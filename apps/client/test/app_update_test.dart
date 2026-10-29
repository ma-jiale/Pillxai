import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_client/data/app_update_controller.dart';
import 'package:pillxai_client/data/backend_connection.dart';
import 'package:pillxai_client/data/terminal_controller.dart';
import 'package:pillxai_client/widgets/app_update_dialog.dart';

import 'terminal_ui_test.dart' show FakeHost;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pillxai/updates-test');
  late Map<String, dynamic> device;
  late Map<String, dynamic> manifest;
  late List<String> calls;
  late BackendConnection backend;
  late TerminalController terminal;
  late AppUpdateController updates;
  late int httpStatus;
  late int apiCompatibility;
  bool withdrawn = false;

  setUp(() {
    calls = [];
    httpStatus = 200;
    apiCompatibility = 1;
    withdrawn = false;
    device = {
      'version_name': '0.1.0',
      'version_code': 1,
      'package_name': 'com.pillxai.pillxai_client',
      'sdk': 35,
      'abis': ['arm64-v8a'],
      'auto_download': false,
      'can_install': true,
      'downloading': false,
      'installing': false,
    };
    manifest = {
      'version_code': 2,
      'version_name': '0.1.1',
      'package_name': device['package_name'],
      'sha256': 'a' * 64,
      'size_bytes': 1000,
      'min_android_sdk': 24,
      'abis': ['arm64-v8a'],
      'min_api': 1,
      'max_api': 1,
      'notes': '改善药盒识别。',
    };
    final client = api.ApiClient(basePath: 'https://example.test/pillxai');
    client.client = MockClient((request) async {
      expect(request.url.path, '/pillxai/releases/android');
      return http.Response(
        jsonEncode({
          'api_compatibility': apiCompatibility,
          'release': withdrawn ? null : manifest,
        }),
        httpStatus,
        headers: {'content-type': 'application/json'},
      );
    });
    backend = BackendConnection(client: client);
    terminal = TerminalController(backend, FakeHost({}))..initialized = true;
    updates = AppUpdateController(
      backend,
      terminal,
      channel: channel,
      supported: true,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'info') return device;
          if (call.method == 'autoDownload') {
            device['auto_download'] = call.arguments;
          }
          if (call.method == 'download') {
            expect(
              (call.arguments as Map)['url'],
              'https://example.test/pillxai/releases/android/packages/${manifest['sha256']}',
            );
            device['downloading'] = true;
          }
          if (call.method == 'install') device['installing'] = true;
          return null;
        });
  });
  tearDown(() {
    updates.dispose();
    terminal.dispose();
    backend.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('automatic download is persisted and never auto-installs', () async {
    await updates.initialize();
    expect(updates.release?.versionCode, 2);
    expect(calls, isNot(contains('download')));
    await updates.setAutoDownload(true);
    expect(calls, contains('autoDownload'));
    expect(calls, contains('download'));
    expect(calls, isNot(contains('install')));
  });

  test('active claim prevents automatic download and installation', () async {
    terminal.view = {
      'claim_intent': {'id': 'claim'},
      'state': {'phase': 'idle'},
    };
    device['auto_download'] = true;
    await updates.initialize();
    expect(calls, isNot(contains('download')));
    device['ready_sha256'] = manifest['sha256'];
    await updates.refresh();
    await updates.install();
    expect(calls, isNot(contains('install')));
    expect(updates.error, contains('同步'));
  });

  test(
    'checks server compatibility and withdrawal again before installation',
    () async {
      device['ready_sha256'] = manifest['sha256'];
      await updates.initialize();
      expect(updates.ready, isTrue);
      withdrawn = true;
      await updates.install();
      expect(calls, isNot(contains('install')));
      expect(updates.release, isNull);
    },
  );

  test('idle downloaded release reaches native installation gate', () async {
    device['ready_sha256'] = manifest['sha256'];
    await updates.initialize();
    await updates.install();
    expect(calls.where((c) => c == 'install').length, 1);
    expect(updates.installing, isTrue);
    expect(calls, isNot(contains('confirm')));
  });

  test('unavailable check invalidates previously available release', () async {
    await updates.initialize();
    expect(updates.release, isNotNull);
    httpStatus = 503;
    await updates.check();
    expect(updates.release, isNull);
    expect(updates.error, isNotNull);
  });

  test('incompatible server never offers download', () async {
    apiCompatibility = 2;
    device['auto_download'] = true;
    await updates.initialize();
    expect(updates.release, isNull);
    expect(updates.error, contains('不兼容'));
    expect(calls, isNot(contains('download')));
  });

  test('same or older build never offers a downgrade', () async {
    device['version_code'] = 2;
    await updates.initialize();
    expect(updates.release, isNull);
    expect(updates.message, contains('最新'));
  });

  for (final width in [390.0, 1280.0]) {
    testWidgets('update dialog fits width $width and gates installation', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      updates.device = {...device, 'ready_sha256': manifest['sha256']};
      updates.release = api.AndroidRelease.fromJson(manifest);
      terminal.view = {
        'state': {'phase': 'dispensing'},
      };
      await tester.pumpWidget(
        MaterialApp(home: AppUpdateDialog(updates: updates)),
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '安装更新'))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      updates.device = {
        ...device,
        'installing': true,
        'confirmation_ready': true,
      };
      await tester.pumpWidget(
        MaterialApp(
          home: AppUpdateDialog(key: UniqueKey(), updates: updates),
        ),
      );
      expect(find.text('继续系统安装'), findsOneWidget);
      expect(find.text('取消安装'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

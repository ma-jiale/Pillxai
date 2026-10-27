import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_client/data/backend_connection.dart';
import 'package:pillxai_client/data/terminal_controller.dart';
import 'package:pillxai_client/data/terminal_host.dart';
import 'package:pillxai_client/screens/terminal_execution_panel.dart';
import 'package:pillxai_client/screens/terminal_device_dialog.dart';
import 'package:pillxai_client/screens/task_history_dialog.dart';
import 'package:pillxai_client/theme/app_theme.dart';

class FakeHost implements TerminalHost {
  FakeHost(this.value);
  final Map<String, dynamic> value;
  final events = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final operations = <String>[];
  @override
  bool get supported => true;
  @override
  Stream<Map<String, dynamic>> get updates => events.stream;
  @override
  Future<void> initialize() async {}
  @override
  Future<dynamic> command(
    String operation, [
    Map<String, dynamic> data = const {},
  ]) async {
    operations.add(operation);
    if (operation == 'view') return value;
    if (operation == 'ports') return ['COM7'];
    if (operation == 'pending') return [];
    if (operation == 'pause' || operation == 'resume') {
      (value['state'] as Map)['phase'] = operation == 'pause'
          ? 'paused'
          : 'running';
      events.add(value);
    }
    return null;
  }

  @override
  Future<void> close() async {
    unawaited(events.close());
  }
}

Map<String, dynamic> snapshot() => {
  'terminal_id': 'terminal',
  'recognized': true,
  'pending_count': 0,
  'state': {
    'phase': 'running',
    'batch': 0,
    'count': 7,
    'connected': true,
    'matrix_issued': true,
    'permitted': true,
    'message': '正在分药，可以投药。',
  },
  'task': {
    'id': 'task',
    'plan_id': 'plan',
    'device_id': 'device',
    'terminal_id': 'terminal',
    'owner_id': 'owner',
    'revision': 1,
    'state': 'started',
    'sequence': 0,
    'completed_batches': [],
    'counts': [7],
    'started_at': '2026-10-26T08:00:00Z',
    'updated_at': '2026-10-26T08:00:00Z',
    'labels': ['AABB'],
    'device': {
      'id': 'device',
      'revision': 1,
      'configuration': {
        'name': '模拟机',
        'identity': 'test',
        'terminal_id': 'terminal',
        'mode': 'simulator',
        'rows': [2, 1, 0, 3],
      },
    },
    'plan': {
      'id': 'plan',
      'resident_id': 'resident',
      'resident_revision': 1,
      'resident_name': '模拟长者',
      'bed': 'A-01',
      'business_date': '2026-10-26',
      'created_at': '2026-10-26T08:00:00Z',
      'requested_days': 7,
      'split_meals': false,
      'dates': ['2026-10-26'],
      'slots': ['早', '午', '晚'],
      'trays': [],
      'sources': [],
      'settings': {
        'timezone': 'Asia/Shanghai',
        'preparation_days': 7,
        'split_meals': false,
        'bedtime_enabled': false,
        'start_tomorrow': false,
        'revision': 1,
      },
    },
    'batches': [
      {
        'index': 0,
        'tray': 0,
        'prescription_id': 'p',
        'medicine_id': 'm',
        'name': '模拟半片药物',
        'strength': '10 mg',
        'feed_form': 'half',
        'purpose': '餐前盘',
        'total': 14,
        'matrix': [
          [2, 2, 2, 2, 2, 2, 2],
          [0, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 0, 0],
        ],
        'parameters': {
          'prescription_id': 'p',
          'medicine_id': 'm',
          'revision': 1,
          'turntable': 1,
          'gate': .5,
          'simulation_only': true,
        },
      },
    ],
  },
};

void main() {
  setUpAll(() async {
    await (FontLoader('NotoSansSC')
          ..addFont(rootBundle.load('assets/fonts/NotoSansCJKsc-Regular.otf')))
        .load();
  });
  testWidgets('执行记录查询已结束任务并区分计划量和反馈量', (tester) async {
    final data = Map<String, dynamic>.from(snapshot()['task'] as Map)
      ..['state'] = 'completed'
      ..['completed_batches'] = [0]
      ..['counts'] = [14];
    final client = api.ApiClient(basePath: 'http://localhost');
    client.client.close();
    client.client = MockClient((request) async {
      expect(request.url.queryParameters['active'], 'false');
      return http.Response(
        jsonEncode([data]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final backend = BackendConnection(client: client);
    final host = FakeHost(snapshot());
    final terminal = TerminalController(backend, host);
    await tester.pumpWidget(
      MaterialApp(
        theme: createTheme(),
        home: Scaffold(body: TaskHistoryDialog(terminal: terminal)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('模拟长者 · 已完成'));
    await tester.pumpAndSettle();
    expect(find.text('计划 14 颗 · 反馈 14 颗 · 收到完成反馈'), findsOneWidget);
    expect(find.text('以下是机器累计计数；不代表逐格实测数量。'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    terminal.dispose();
    unawaited(host.close());
    backend.dispose();
  });
  for (final size in [const Size(1280, 800), const Size(390, 844)]) {
    testWidgets('本机任务界面暂停恢复、连接锁定与取盒状态 $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = api.ApiClient(basePath: 'http://localhost');
      client.client.close();
      client.client = MockClient((_) async => http.Response('[]', 200));
      final backend = BackendConnection(client: client)
        ..account = api.AccountView(
          id: 'owner',
          username: 'tester',
          displayName: '测试',
          role: api.Role.admin,
          canMaintain: true,
          active: true,
          revision: 1,
        );
      final host = FakeHost(snapshot());
      final terminal = TerminalController(backend, host);
      await terminal.initialize();
      const root = ValueKey('terminal-capture');
      await tester.pumpWidget(
        RepaintBoundary(
          key: root,
          child: MaterialApp(
            theme: createTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: TerminalExecutionPanel(terminal: terminal),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('已摆 7 / 14 颗'), findsOneWidget);
      await tester.tap(find.text('暂停'));
      await tester.pumpAndSettle();
      expect(host.operations, contains('pause'));
      expect(find.text('继续'), findsOneWidget);
      await tester.tap(find.text('继续'));
      await tester.pumpAndSettle();
      expect(host.operations, contains('resume'));
      await tester.tap(find.text('设备与反馈'));
      await tester.pumpAndSettle();
      expect(find.byType(TerminalDeviceDialog), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '保存连接'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      (host.value['state'] as Map).addAll(<String, Object>{
        'phase': 'collecting',
        'message': '请取出药盒。',
      });
      host.events.add(host.value);
      await tester.pumpAndSettle();
      expect(find.text('模拟取出药盒'), findsOneWidget);
      expect(find.text('模拟半片药物'), findsNothing);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('TERMINAL_CAPTURE')) {
        await tester.runAsync(() async {
          final image = await tester
              .renderObject<RenderRepaintBoundary>(find.byKey(root))
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('../../.tools/ui-review')
            ..createSync(recursive: true);
          await File('${dir.path}/terminal-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      host.value['task'] = null;
      host.events.add(host.value);
      await tester.pumpWidget(const SizedBox());
      terminal.dispose();
      unawaited(host.close());
      backend.dispose();
    });
  }
}

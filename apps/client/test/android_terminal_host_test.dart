import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:pillxai_client/screens/connected_workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillxai_client/data/terminal_host_android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pillxai/terminal');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test('Android proxy propagates permission denial and can retry without claiming connection', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'initialize') {
        return jsonEncode({
          'platform': 'android',
          'state': {'connected': false},
        });
      }
      final operation = (call.arguments as Map)['operation'] as String;
      calls.add(operation);
      if (operation == 'connect') {
        throw PlatformException(code: 'permission', message: '附近设备权限未允许');
      }
      if (operation == 'ports') {
        return jsonEncode([
          {'address': 'AA:BB:CC:DD:EE:FF', 'name': 'dispenser01'},
        ]);
      }
      return 'null';
    });
    final host = AndroidTerminalHost();
    final updates = <Map<String, dynamic>>[];
    final subscription = host.updates.listen(updates.add);
    await host.initialize();
    await expectLater(
      host.command('connect'),
      throwsA(isA<PlatformException>()),
    );
    expect(updates.single['state']['connected'], false);
    expect((await host.command('ports') as List).single['name'], 'dispenser01');
    await host.close();
    await subscription.cancel();
    expect(calls, ['connect', 'ports', 'shutdown']);
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'Android proxy cannot detach through shutdown while the service has a task',
    () async {
      var active = true;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'initialize') return '{"platform":"android"}';
        final operation = (call.arguments as Map)['operation'];
        if (operation == 'shutdown' && active) {
          throw PlatformException(code: 'busy');
        }
        return operation == 'view' ? '{"task":{"id":"retained"}}' : 'null';
      });
      final host = AndroidTerminalHost();
      await expectLater(host.close(), throwsA(isA<PlatformException>()));
      expect((await host.command('view') as Map)['task']['id'], 'retained');
      active = false;
      await host.close();
      messenger.setMockMethodCallHandler(channel, null);
    },
  );
  testWidgets(
    'Android root back backgrounds the Activity instead of ending tasks',
    (tester) async {
      const window = MethodChannel('pillxai/window');
      final calls = <String>[];
      messenger.setMockMethodCallHandler(window, (call) async {
        calls.add(call.method);
        return null;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ConnectedWorkspace(
            accent: Colors.black,
            onAccentChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(calls, ['background']);
      await tester.pumpWidget(const SizedBox());
      messenger.setMockMethodCallHandler(window, null);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

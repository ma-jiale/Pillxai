import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillxai_client/data/android_runtime.dart';
import 'package:pillxai_client/main.dart';
import 'package:pillxai_client/screens/device_disconnected_dialog.dart';
import 'package:pillxai_client/screens/motor_stall_dialog.dart';
import 'package:pillxai_execution_core/execution_core.dart';

import 'connected_prescriptions_test.dart' show actorId;
import 'support/production_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pillxai/bluetooth');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  for (final release in [true, false]) {
    testWidgets(
      'stall popup is automatic, defaults checked, confirm release=$release',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = ProductionFixture();
        addTearDown(fixture.dispose);
        await tester.pumpWidget(
          PillxaiApp(backend: fixture.backend, terminalHost: fixture.host),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('login-account')),
          'admin',
        );
        await tester.enterText(
          find.byKey(const ValueKey('login-password')),
          'fixture-password',
        );
        await tester.tap(find.byKey(const ValueKey('login-submit')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('nav-0')));
        await tester.pumpAndSettle();
        fixture.host.value['stall_notices'] = [
          {'id': 'notice-2', 'motor': 2, 'owner_id': actorId, 'seen': false},
        ];
        fixture.host.events.add(fixture.host.value);
        await tester.pumpAndSettle();
        fixture.host.events.add(fixture.host.value);
        await tester.pumpAndSettle();
        expect(find.byType(MotorStallDialog), findsOneWidget);
        expect(find.text('摆药机的 2 号电机堵转，请停止投料并排查。'), findsOneWidget);
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isTrue,
        );
        expect(fixture.host.stallConfirmations, isEmpty);
        if (!release) {
          await tester.tap(find.byType(CheckboxListTile));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();
        expect(fixture.host.stallConfirmations, [
          {'id': 'notice-2', 'release': release},
        ]);
        expect(find.byType(MotorStallDialog), findsNothing);
        expect(fixture.host.operations, isNot(contains('resume')));
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'global notice appears once on another page, clears stale dialogs and returns home without reconnect',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = ProductionFixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(
        PillxaiApp(backend: fixture.backend, terminalHost: fixture.host),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('login-account')),
        'admin',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'fixture-password',
      );
      await tester.tap(find.byKey(const ValueKey('login-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-0')));
      await tester.pumpAndSettle();
      showDialog<void>(
        context: tester.element(find.byType(Scaffold).first),
        builder: (_) => const AlertDialog(title: Text('旧确认窗口')),
      );
      await tester.pumpAndSettle();
      fixture.host.value['disconnect_notice'] = {
        'task_id': 'lost-task',
        'owner_id': actorId,
      };
      (fixture.host.value['state'] as Map)['connected'] = false;
      fixture.host.events.add(fixture.host.value);
      await tester.pumpAndSettle();
      fixture.host.events.add(fixture.host.value);
      await tester.pumpAndSettle();
      expect(find.byType(DeviceDisconnectedDialog), findsOneWidget);
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();
      expect(find.byType(DeviceDisconnectedDialog), findsNothing);
      expect(find.text('旧确认窗口'), findsNothing);
      expect(
        find.byKey(const ValueKey('page-title-dispensing')),
        findsOneWidget,
      );
      expect(
        fixture.host.operations.where(
          (op) => op == 'dismiss_disconnect_notice',
        ),
        hasLength(1),
      );
      expect(fixture.host.operations, isNot(contains('connect')));
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final code in [
    'bluetooth_disconnected',
    'bluetooth_timeout',
    'bluetooth_io',
  ]) {
    test('transport preserves distinction for $code', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: code),
      );
      final transport = AndroidBluetoothTransport('test');
      final matcher = code == 'bluetooth_disconnected'
          ? isA<DeviceDisconnected>()
          : isA<PlatformException>();
      await expectLater(transport.read(), throwsA(matcher));
      await expectLater(transport.write(Uint8List(0)), throwsA(matcher));
    });
  }
  testWidgets(
    'disconnect notice requires explicit acknowledgement and survives a save failure',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => DeviceDisconnectedDialog(
                    onAcknowledged: () async {
                      if (++attempts == 1) throw StateError('disk');
                    },
                  ),
                ),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('show'));
      await tester.pumpAndSettle();
      expect(find.text('摆药机连接已断开'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(DeviceDisconnectedDialog), findsOneWidget);
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();
      expect(find.text('确认未保存，请重试。'), findsOneWidget);
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();
      expect(find.byType(DeviceDisconnectedDialog), findsNothing);
    },
  );
}

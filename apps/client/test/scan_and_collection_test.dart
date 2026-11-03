import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillxai_client/main.dart';
import 'package:pillxai_client/screens/collection_reminder_dialog.dart';
import 'package:pillxai_client/screens/scan_resident_dialog.dart';
import 'package:pillxai_client/screens/device_disconnected_dialog.dart';

import 'support/production_fixture.dart';

Future<ProductionFixture> login(WidgetTester tester) async {
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
  await tester.enterText(find.byKey(const ValueKey('login-account')), 'admin');
  await tester.enterText(
    find.byKey(const ValueKey('login-password')),
    'fixture-password',
  );
  await tester.tap(find.byKey(const ValueKey('login-submit')));
  await tester.pumpAndSettle();
  return fixture;
}

void main() {
  for (final skipped in [false, true]) {
    testWidgets(
      'collection reminder requires device removal, skipped=$skipped',
      (tester) async {
        final fixture = await login(tester);
        fixture.host.value['task'] = fixture.task;
        fixture.task['skipped_batches'] = skipped ? [0] : [];
        fixture.host.feedback('collecting');
        await tester.pumpAndSettle();
        expect(find.byType(CollectionReminderDialog), findsOneWidget);
        expect(
          find.text(
            skipped ? '当前长者的摆药任务已结束，部分药物已跳过，请及时取走药盒。' : '当前长者的摆药任务已完成，请及时取走药盒。',
          ),
          findsOneWidget,
        );
        await tester.tapAt(const Offset(5, 5));
        await tester.binding.handlePopRoute();
        fixture.host.events.add(fixture.host.value);
        await tester.pumpAndSettle();
        expect(find.byType(CollectionReminderDialog), findsOneWidget);
        (fixture.host.value['state'] as Map)['uid'] = null;
        fixture.host.events.add(fixture.host.value);
        await tester.pumpAndSettle();
        expect(find.byType(CollectionReminderDialog), findsOneWidget);
        fixture.host.feedback('closing');
        await tester.pumpAndSettle();
        expect(find.byType(CollectionReminderDialog), findsNothing);
        expect(fixture.host.operations, isNot(contains('cancel')));
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('disconnection supersedes collection reminder', (tester) async {
    final fixture = await login(tester);
    fixture.host.value['task'] = fixture.task;
    fixture.host.feedback('collecting');
    await tester.pumpAndSettle();
    fixture.host.value['disconnect_notice'] = {'task_id': fixture.task['id']};
    fixture.host.feedback('deleting');
    await tester.pumpAndSettle();
    expect(find.byType(CollectionReminderDialog), findsNothing);
    expect(find.byType(DeviceDisconnectedDialog), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'scan entry opens once, unknown/removal invalidate plan, confirmed plan starts',
    (tester) async {
      final fixture = await login(tester);
      await tester.tap(find.byKey(const ValueKey('scan-resident')));
      await tester.pumpAndSettle();
      expect(find.byType(ScanResidentDialog), findsOneWidget);
      expect(
        fixture.host.operations.where((op) => op == 'open_identification'),
        hasLength(1),
      );
      final state = fixture.host.value['state'] as Map;
      state['barcode'] = 'unknown';
      fixture.host.events.add(fixture.host.value);
      await tester.pumpAndSettle();
      expect(find.text('未找到该药盒对应的长者，请核对标签或更换药盒。'), findsOneWidget);
      expect(find.byKey(const ValueKey('confirm-dispense')), findsNothing);
      state['barcode'] = '000010';
      fixture.host.events.add(fixture.host.value);
      await tester.pumpAndSettle();
      expect(find.text('确认摆药信息'), findsOneWidget);
      expect(find.text('测试药 A'), findsOneWidget);
      expect(fixture.host.operations, isNot(contains('claim_intent')));
      state['barcode'] = null;
      fixture.host.events.add(fixture.host.value);
      await tester.pumpAndSettle();
      expect(find.text('确认摆药信息'), findsNothing);
      state['barcode'] = '000010';
      fixture.host.events.add(fixture.host.value);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('confirm-dispense')),
      );
      await tester.tap(find.byKey(const ValueKey('confirm-dispense')));
      await tester.pumpAndSettle();
      expect(
        fixture.host.operations,
        containsAllInOrder([
          'open_identification',
          'claim_intent',
          'attach',
          'begin',
        ]),
      );
      expect(
        fixture.host.operations.where((op) => op == 'open_identification'),
        hasLength(1),
      );
      expect(find.byType(ScanResidentDialog), findsNothing);
      expect(find.text('暂停'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('closing empty scan retracts without creating a task', (
    tester,
  ) async {
    final fixture = await login(tester);
    await tester.tap(find.byKey(const ValueKey('scan-resident')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(fixture.host.operations, contains('close_identification'));
    expect(fixture.host.operations, isNot(contains('claim_intent')));
    expect(find.byType(ScanResidentDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

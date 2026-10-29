import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillxai_client/main.dart';
import 'package:pillxai_client/screens/plan_preview_page.dart';
import 'package:pillxai_client/widgets/dispensing_medicine_cards.dart';

import 'support/production_fixture.dart';

void main() {
  for (final outcome in [
    'replace',
    'cancel_wrong',
    'cancel_correct',
    'cancel_empty',
  ]) {
    testWidgets('药盒检查保持弹窗，关闭须先取盒：$outcome', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = ProductionFixture();
      addTearDown(fixture.dispose);
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        PillxaiApp(backend: fixture.backend, terminalHost: fixture.host),
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-account')),
        'admin',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'fixture-password',
      );
      await tap(find.byKey(const ValueKey('login-submit')));
      await tap(find.text('开始摆药'));
      await tap(find.text('开仓放入药盒'));
      final state = fixture.host.value['state'] as Map;
      final correct = outcome == 'cancel_correct';
      final empty = outcome == 'cancel_empty';
      state['barcode'] = empty
          ? null
          : correct
          ? '000010'
          : '000011';
      fixture.host.feedback(
        correct ? 'ready' : 'recognizing',
        recognized: correct,
      );
      if (!correct && !empty) {
        state['message'] = '药盒与服务端长者不匹配，请核对并更换正确的药盒。';
        fixture.host.events.add(fixture.host.value);
      }
      await tester.pumpAndSettle();
      expect(find.byType(ServerPlanDialog), findsOneWidget);
      expect(
        find.byType(DispensingMedicineCards, skipOffstage: false),
        findsNothing,
      );
      final start = find.byKey(const ValueKey('confirm-dispense'));
      expect(tester.widget<FilledButton>(start).onPressed == null, !correct);
      // Neither a barrier tap nor system Back bypasses the explicit close path.
      await tester.tapAt(const Offset(5, 5));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ServerPlanDialog), findsOneWidget);
      expect(fixture.host.operations, isNot(contains('begin')));

      final close = find.descendant(
        of: find.byType(ServerPlanDialog),
        matching: find.widgetWithText(TextButton, '关闭'),
      );
      if (outcome != 'replace' && !empty) {
        await tap(close);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('preparation-box-status')),
            matching: find.textContaining('请先取出药盒'),
          ),
          findsOneWidget,
        );
        expect(find.byType(ServerPlanDialog), findsOneWidget);
      }
      final cancelCount = fixture.host.operations
          .where((o) => o == 'cancel_preparation')
          .length;
      state['barcode'] = null;
      fixture.host.feedback('recognizing', recognized: false);
      await tester.pumpAndSettle();
      expect(
        fixture.host.operations.where((o) => o == 'cancel_preparation').length,
        cancelCount,
      );
      expect(
        find.byType(DispensingMedicineCards, skipOffstage: false),
        findsNothing,
      );
      if (outcome == 'replace') {
        state['barcode'] = '000010';
        fixture.host.feedback('ready', recognized: true);
        await tester.pumpAndSettle();
        expect(
          find.byType(DispensingMedicineCards, skipOffstage: false),
          findsNothing,
        );
        await tap(start);
        expect(find.byType(ServerPlanDialog), findsNothing);
        expect(find.byType(DispensingMedicineCards), findsOneWidget);
        expect(fixture.host.operations, contains('begin'));
      } else {
        await tap(close);
        expect(
          find.byType(ServerPlanDialog),
          findsOneWidget,
        ); // Wait for ACK + DONE.
        expect(fixture.host.operations, isNot(contains('begin')));
        fixture.host.feedback('cancelled');
        await tester.pumpAndSettle();
        expect(find.byType(ServerPlanDialog), findsNothing);
        expect(
          find.byType(DispensingMedicineCards, skipOffstage: false),
          findsNothing,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

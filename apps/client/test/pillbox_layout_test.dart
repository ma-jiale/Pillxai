import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_client/data/settings_controller.dart';
import 'package:pillxai_client/screens/pillbox_layout_dialog.dart';
import 'package:pillxai_client/widgets/app_menu.dart';
import 'package:pillxai_client/widgets/medicine_pattern.dart';
import 'package:pillxai_client/widgets/server_plan_pattern.dart';

import 'connected_prescriptions_test.dart' show connection, jsonResponse;
import 'server_planning_test.dart' show previewJson, settingsJson;

void main() {
  for (final night in [false, true]) {
    testWidgets('edit shared pillbox without a device, bedtime=$night', (
      tester,
    ) async {
      final initial = {
        ...settingsJson,
        'bedtime_enabled': night,
        'box_slot_order': [0, 3, 1, 2],
      };
      var writes = 0;
      final backend =
          connection((request) async {
              expect(request.url.path, '/settings');
              final data = jsonDecode(request.body);
              expect(data['box_slot_order'], [2, 3, 1, 0]);
              expect(data['expected_revision'], 1);
              writes++;
              return jsonResponse({
                ...initial,
                'box_slot_order': data['box_slot_order'],
                'revision': 2,
              });
            })
            ..settings = api.AppSettings.fromJson(initial)
            ..account = api.AccountView(
              id: 'a',
              username: 'a',
              displayName: 'a',
              role: api.Role.admin,
              canMaintain: false,
              active: true,
              revision: 1,
            );
      final settings = SettingsController(backend, onSaved: () {});
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => PillboxLayoutDialog(settings: settings),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.byType(AppSelect<int>), findsNWidgets(night ? 4 : 3));
      expect(find.text('睡前'), night ? findsOneWidget : findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(AppSelect<int>).first,
          matching: find.byType(OutlinedButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, '晚'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存映射'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(settings.saved.boxSlotOrder, [2, 3, 1, 0]);
      await tester.pumpWidget(const SizedBox());
      settings.dispose();
      backend.dispose();
    });
  }

  testWidgets('pillbox preview keeps planned quantities with their period', (
    tester,
  ) async {
    final snapshot = previewJson()['snapshot'] as Map<String, dynamic>;
    snapshot['settings'] = {
      ...settingsJson,
      'box_slot_order': [2, 3, 1, 0],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: ServerPlanPattern(snapshot: api.PlanSnapshot.fromJson(snapshot)!),
      ),
    );
    final plan = tester
        .widget<MedicinePatternDialog>(find.byType(MedicinePatternDialog))
        .plan;
    expect(plan.slots, ['晚', '午', '早']);
    expect(plan.medicines.first.particles.first, [0, 0, 25]);
  });
}

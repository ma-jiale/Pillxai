import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillxai_client/models/demo_model.dart';
import 'package:pillxai_client/screens/prescriptions_page.dart';

void main() {
  testWidgets('版本记录和删除药物进入三点菜单，删除必须确认具体对象', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = DemoModel(autoTick: false);
    addTearDown(model.dispose);
    final resident = model.selectedResident;
    final medicine = resident.medicines.first;
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrescriptionsPage(
            model: model,
            onVersions: (_, drug) => calls.add('versions:${drug.id}'),
            onDelete: (person, drug) async =>
                calls.add('delete:${drug?.id ?? person.id}'),
          ),
        ),
      ),
    );
    Future<void> menu(String tooltip, String item) async {
      final target = find.byTooltip(tooltip);
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      await tester.tap(find.text(item));
      await tester.pumpAndSettle();
    }

    expect(find.text('版本记录'), findsNothing);
    final actions = '${medicine.name}更多操作';
    await menu(actions, '版本记录');
    await menu(actions, '删除药物');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(calls, ['versions:${medicine.id}']);
    await menu(actions, '删除药物');
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();
    await menu('${resident.name}更多操作', '删除长者');
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();
    expect(calls, [
      'versions:${medicine.id}',
      'delete:${medicine.id}',
      'delete:${resident.id}',
    ]);
  });
}

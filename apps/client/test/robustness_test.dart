import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillxai_client/main.dart';
import 'package:pillxai_client/models/demo_model.dart';
import 'package:pillxai_client/models/dose_rules.dart';
import 'package:pillxai_client/models/preparation_plan.dart';
import 'package:pillxai_client/screens/preparation_page.dart';
import 'package:pillxai_client/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('NotoSansSC')
          ..addFont(rootBundle.load('assets/fonts/NotoSansCJKsc-Regular.otf')))
        .load();
  });

  Future<DemoModel> openApp(
    WidgetTester tester, {
    DemoModel? model,
    Size size = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = model ?? DemoModel(autoTick: false);
    addTearDown(state.dispose);
    await tester.pumpWidget(PillxaiApp(model: state, initiallySignedIn: true));
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  test('共享剂量规则：解析、有限数值、半片、睡前及全零', () {
    expect(parseDoseInput(' 0.5 '), .5);
    expect(parseDoseInput(''), 0);
    for (final dose in [null, -1.0, double.nan, double.infinity, 1e308]) {
      expect(
        validateDose(dose, slot: 0, half: false, bedtimeEnabled: true),
        isNotNull,
      );
    }
    expect(validateDose(.5, slot: 0, half: true, bedtimeEnabled: true), isNull);
    expect(
      validateDose(.5, slot: 0, half: false, bedtimeEnabled: true),
      isNotNull,
    );
    expect(
      validateDose(1, slot: 3, half: false, bedtimeEnabled: false),
      contains('睡前格'),
    );
    expect(validateDailyDose([0, 0, 0, 0]), isNotNull);
  });

  test('范围外睡前药不阻塞；范围内错误不消失；计划列表不可改写', () {
    final date = DateTime(2026, 10, 26);
    final resident = Resident(
      id: 'r',
      name: '长者',
      bed: '',
      medicines: [
        const Medicine(id: 'day', name: '早药', strength: '1mg'),
        Medicine(
          id: 'expired',
          name: '睡前药',
          strength: '1mg',
          doses: const DoseSchedule(morning: 0, noon: 0, evening: 0, night: 1),
          endDate: DateTime(2026, 10, 25),
        ),
        Medicine(
          id: 'future',
          name: '未来睡前药',
          strength: '1mg',
          doses: const DoseSchedule(morning: 0, noon: 0, evening: 0, night: 1),
          startDate: DateTime(2026, 11, 20),
        ),
      ],
    );
    final plan = PreparationPlan(resident, date, 7, bedtime: false);
    expect(plan.issue, isNull);
    expect(plan.medicines.map((m) => m.id), ['day']);
    expect(() => plan.medicines.clear(), throwsUnsupportedError);
    final future = PreparationPlan(
      resident,
      DateTime(2026, 11, 20),
      1,
      bedtime: false,
    );
    expect(future.hasDemand, isTrue);
    expect(future.issue, contains('睡前格'));
    expect(future.canStart, isFalse);
  });

  testWidgets('仅睡前用药仍在清单中，错误计划不可启动，修正后正常开始', (tester) async {
    final model = DemoModel(autoTick: false);
    final resident = Resident(
      id: 'night',
      name: '睡前长者',
      bed: '',
      medicines: [
        const Medicine(
          id: 'm',
          name: '睡前药',
          strength: '1mg',
          doses: DoseSchedule(morning: 0, noon: 0, evening: 0, night: 1),
        ),
      ],
    );
    model.residents
      ..clear()
      ..add(resident);
    model.selectedResidentId = resident.id;
    await openApp(tester, model: model);
    expect(find.textContaining('请先启用睡前格'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('prepare-night')));
    model.boxFeedback.value = BoxFeedback.match;
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('confirm-dispense')))
          .onPressed,
      isNull,
    );
    expect(model.startPreparedTask(model.planFor(resident)), isFalse);
    await tap(tester, find.text('取消'));
    model.saveSettings(days: 7, split: true, night: true, tomorrow: false);
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('prepare-night')));
    model.boxFeedback.value = BoxFeedback.match;
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('confirm-dispense')));
    expect(model.active, isTrue);
    expect(model.currentMedicine.target, 7);
    expect(tester.takeException(), isNull);
  });

  testWidgets('大数量图案保持有界并可点按查看精确数量', (tester) async {
    await openApp(tester);
    final plan = PreparationPlan(
      Resident(
        id: 'large',
        name: '长者',
        bed: '',
        medicines: [
          const Medicine(
            id: 'm',
            name: '大数量测试药',
            strength: '1mg',
            doses: DoseSchedule(morning: 1000000, noon: 0, evening: 0),
          ),
        ],
      ),
      DateTime(2026, 10, 26),
      7,
      bedtime: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: createTheme(),
        home: Scaffold(body: PatternDialog(plan: plan)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1000000颗\n点击查看'), findsNWidgets(7));
    expect(find.byType(Container).evaluate().length, lessThan(100));
    await tap(tester, find.byKey(const ValueKey('pattern-count-0-0')));
    expect(find.textContaining('大数量测试药 1000000颗'), findsOneWidget);
    expect(plan.medicines.single.target, 7000000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('白色强调色保留填充原色，文字按钮仍清楚可读', (tester) async {
    await openApp(tester);
    await tap(tester, find.byKey(const ValueKey('nav-2')));
    await tap(tester, find.byKey(const ValueKey('settings-appearance')));
    await tester.enterText(
      find.byKey(const ValueKey('custom-accent-input')),
      '#FFFFFF',
    );
    await tap(tester, find.widgetWithText(TextButton, '应用'));
    await tap(tester, find.byKey(const ValueKey('nav-1')));
    final rich = tester.widget<RichText>(
      find
          .descendant(
            of: find.byKey(const ValueKey('open-history')),
            matching: find.byType(RichText),
          )
          .last,
    );
    final color = rich.text.style!.color!;
    expect(1.05 / (color.computeLuminance() + .05), greaterThanOrEqualTo(4.5));
    expect(createTheme(accent: Colors.white).colorScheme.primary, Colors.white);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(1280, 800), const Size(800, 1280)]) {
    testWidgets('200人名单点选后详情可达，搜索与添加不随名单离屏 $size', (tester) async {
      final model = DemoModel(autoTick: false);
      model.residents.addAll(
        List.generate(
          196,
          (i) =>
              Resident(id: 'extra-$i', name: '新增长者$i', bed: '', medicines: []),
        ),
      );
      await openApp(tester, model: model, size: size);
      await tap(tester, find.byKey(const ValueKey('nav-0')));
      final list = find.byKey(const ValueKey('resident-list-scroll'));
      final target = find.byKey(const ValueKey('resident-extra-195'));
      await tester.scrollUntilVisible(
        target,
        500,
        scrollable: find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        ),
        maxScrolls: 60,
      );
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(model.selectedResidentId, 'extra-195');
      final title = tester.getRect(find.text('当前用药'));
      expect(title.top, greaterThanOrEqualTo(0));
      expect(title.bottom, lessThan(size.height));
      if (size.width > 1000) {
        expect(find.text('添加长者').hitTestable(), findsOneWidget);
        expect(find.byType(TextField).hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('两倍字体窄屏侧栏可滚动且不溢出', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openApp(tester, size: const Size(390, 844));
    expect(
      tester.getSize(find.byKey(const ValueKey('nav-0'))).height,
      greaterThan(72),
    );
    await tap(tester, find.byKey(const ValueKey('nav-2')));
    expect(find.text('设置'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('平板放大字体后七药确认仍可滚动与取消', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final model = await openApp(tester, size: const Size(1024, 600));
    await tap(tester, find.byKey(const ValueKey('prepare-r1')));
    final action = find.byKey(const ValueKey('confirm-dispense'));
    expect(tester.getRect(action).bottom, lessThanOrEqualTo(600));
    await tester.drag(
      find.byKey(const ValueKey('confirmation-medicines')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(model.residents.first.medicines.last.name).hitTestable(),
      findsOneWidget,
    );
    await tap(tester, find.text('取消'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('平板触控目标至少48，药物表单弹键盘后可保存，系统返回保护输入', (tester) async {
    await openApp(tester, size: const Size(1024, 600));
    await tap(tester, find.byKey(const ValueKey('nav-0')));
    final edit = find.byTooltip('编辑示例药 A');
    await tester.ensureVisible(edit);
    expect(tester.getSize(edit).shortestSide, greaterThanOrEqualTo(48));
    await tap(tester, edit);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final name = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == '药物名称',
    );
    await tester.enterText(name, '未保存的修改');
    expect(find.text('保存').hitTestable(), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的修改？'), findsOneWidget);
    await tap(tester, find.text('继续编辑'));
    expect(tester.widget<TextField>(name).controller!.text, '未保存的修改');
    expect(tester.takeException(), isNull);
  });
}

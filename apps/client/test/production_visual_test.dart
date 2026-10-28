import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillxai_client/main.dart';
import 'package:pillxai_client/screens/plan_preview_page.dart';
import 'package:pillxai_client/widgets/preparation_list.dart';
import 'package:pillxai_client/widgets/preparation_confirmation.dart';
import 'package:pillxai_client/widgets/dispensing_medicine_cards.dart';

import 'support/production_fixture.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('NotoSansSC')
          ..addFont(rootBundle.load('assets/fonts/NotoSansCJKsc-Regular.otf')))
        .load();
    await (FontLoader('MaterialIcons')..addFont(
          File(
            '../../.tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
  });
  for (final configuration in [
    (const Size(1280, 800), 1.0),
    (const Size(1024, 600), 1.0),
    (const Size(768, 1173), 1.0),
    (const Size(1173, 768), 1.0),
    (const Size(390, 844), 1.0),
    (const Size(768, 1173), 1.5),
  ]) {
    final (size, scale) = configuration;
    testWidgets('完整正式入口：七药准备、识别、暂停、换药、双盘与取盒 $size 字体 $scale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = ProductionFixture();
      addTearDown(fixture.dispose);
      const root = ValueKey('production-capture');
      Future<void> capture(String stage) async {
        expect(tester.takeException(), isNull, reason: stage);
        if (!const bool.fromEnvironment('PRODUCTION_CAPTURE')) return;
        await tester.runAsync(() async {
          final image = await tester
              .renderObject<RenderRepaintBoundary>(find.byKey(root))
              .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final folder = Directory('../../.tools/ui-review')
            ..createSync(recursive: true);
          await File(
            '${folder.path}/restored-${size.width.toInt()}${scale == 1 ? '' : '-text150'}-$stage.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        RepaintBoundary(
          key: root,
          child: PillxaiApp(
            backend: fixture.backend,
            terminalHost: fixture.host,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture('login');
      await tester.enterText(
        find.byKey(const ValueKey('login-account')),
        'admin',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'fixture-password',
      );
      await tap(find.byKey(const ValueKey('login-submit')));
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/images/avatars/account.png'),
          tester.element(find.byType(PillxaiApp)),
        );
      });
      await tester.pumpAndSettle();
      expect(find.byType(PreparationList), findsOneWidget);
      expect(
        tester.getSize(find.byType(PreparationList)).height,
        lessThan(size.height),
      );
      await capture('queue');
      final title = tester.getTopLeft(
        find.byKey(const ValueKey('page-title-dispensing')),
      );
      await tap(find.text('已连接'));
      await capture('devices');
      await tap(find.byTooltip('配置设备'));
      await capture('device-configuration');
      await tap(find.byTooltip('返回我的设备'));
      await tap(find.byKey(const ValueKey('add-device')));
      await capture('device-search');
      await tap(find.byTooltip('关闭我的设备'));
      await tap(find.byKey(const ValueKey('open-history')));
      await capture('history');
      await tap(find.byKey(const ValueKey('history-history-task')));
      await capture('result-details');
      await tap(find.text('处理经过'));
      expect(find.text('尚无已同步处理事件'), findsOneWidget);
      await tap(find.byTooltip('关闭结果详情'));
      await tester.enterText(
        find.byKey(const ValueKey('history-search')),
        '不存在',
      );
      await tap(find.text('查询'));
      expect(find.text('没有符合条件的记录'), findsOneWidget);
      await tap(find.byKey(const ValueKey('close-history')));
      await tap(find.byKey(const ValueKey('nav-0')));
      expect(
        tester.getTopLeft(
          find.byKey(const ValueKey('page-title-prescriptions')),
        ),
        title,
      );
      await capture('prescriptions');
      await tap(find.byKey(const ValueKey('nav-2')));
      expect(find.text('已连接'), findsNothing);
      await capture('settings');
      await tap(find.byKey(const ValueKey('nav-1')));
      await tap(find.text('开始摆药'));
      expect(find.byType(PreparationConfirmation), findsOneWidget);
      expect(find.byType(PreparationMedicineTable), findsOneWidget);
      await capture('confirm');
      final start = find.byKey(const ValueKey('confirm-dispense'));
      final buttonRect = tester.getRect(start);
      await tester.drag(
        find.byKey(const ValueKey('confirmation-medicines')),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(start), buttonRect);
      await capture('confirm-scrolled');
      await tap(find.text('预览摆药图案'));
      await capture('pattern');
      await tap(find.widgetWithText(FilledButton, '关闭'));
      final previewsBeforeClaim = fixture.previewWrites;
      await tap(find.text('开仓放入药盒'));
      expect(find.byType(ServerPlanDialog), findsOneWidget);
      expect(fixture.host.operations, contains('attach'));
      expect(fixture.host.operations, isNot(contains('begin')));
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      await capture('recognizing');
      fixture.host.feedback('ready', recognized: true);
      await tester.pumpAndSettle();
      expect(find.text('药盒匹配，已确认 服务端长者'), findsOneWidget);
      await capture('ready');
      await tap(start);
      expect(find.byType(ServerPlanDialog), findsNothing);
      expect(fixture.host.operations, contains('begin'));
      expect(fixture.previewWrites, previewsBeforeClaim);
      expect(find.byType(DispensingMedicineCards), findsOneWidget);
      expect(find.text('下一药'), findsOneWidget);
      fixture.host.feedback('running', count: 7);
      await tester.pumpAndSettle();
      await capture('running');
      if (size.width == 1280) {
        expect(
          tester.getRect(find.byKey(const ValueKey('medicine-current-slot'))),
          const Rect.fromLTWH(264, 193, 736, 460),
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('dispense-primary'))).width,
          210,
        );
      }
      await tap(find.text('暂停'));
      expect(fixture.host.operations, contains('pause'));
      await capture('paused');
      await tap(find.byKey(const ValueKey('nav-0')));
      await tap(find.byKey(const ValueKey('nav-1')));
      expect(find.bySemanticsLabel('已摆 7 / 14 颗'), findsOneWidget);
      expect(find.text('继续'), findsOneWidget);
      await tap(find.text('继续'));
      expect(fixture.host.operations, contains('resume'));
      await tap(find.byKey(const ValueKey('adjust-opening')));
      await capture('opening');
      await tap(find.text('完成'));
      await tester.ensureVisible(find.byType(DispensingIdentity));
      fixture.host.feedback('running', batch: 1, count: 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(const ValueKey('medicine-promotion')), findsOneWidget);
      await capture('switch-middle');
      await tester.pumpAndSettle();
      await capture('next-medicine');
      fixture.host.feedback(
        'recognizing',
        batch: 4,
        count: 0,
        recognized: false,
      );
      await tester.pumpAndSettle();
      expect(find.text('已换好，继续'), findsNothing);
      await capture('change-tray');
      fixture.host.feedback('ready', recognized: false);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('dispense-primary')),
            )
            .onPressed,
        isNull,
      );
      fixture.host.feedback('ready', recognized: true);
      await tester.pumpAndSettle();
      await tap(find.text('已换好，继续'));
      expect(fixture.host.operations, contains('continue_tray'));
      fixture.host.feedback('recovery');
      await tester.pumpAndSettle();
      await capture('recovery');
      fixture.host.feedback('collecting');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('collection-status')), findsOneWidget);
      expect(find.byType(DispensingMedicineCards), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '开始摆药'))
            .onPressed,
        isNull,
      );
      await capture('collection');
      fixture.host.feedback('closing');
      await tester.pumpAndSettle();
      await capture('closing');
      fixture.host.value['task'] = null;
      fixture.host.feedback('idle');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('collection-status')), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '开始摆药'))
            .onPressed,
        isNotNull,
      );
      await capture('released');
      await tap(find.text('提前准备 1'));
      expect(find.text('测试长者'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '不存在');
      await tester.pumpAndSettle();
      expect(find.text('没有找到匹配的长者'), findsOneWidget);
      fixture.failQueue = true;
      await tap(find.byTooltip('刷新待摆清单'));
      expect(find.text('清单读取失败'), findsOneWidget);
      expect(find.text('提前准备 0'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

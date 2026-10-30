import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillxai_client/main.dart';

import 'support/navigation.dart';
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

  for (final size in [const Size(1280, 800), const Size(390, 844)]) {
    testWidgets('正式入口：账户设置、折叠导航与页面状态 $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = ProductionFixture();
      addTearDown(fixture.dispose);
      const root = ValueKey('sidebar-capture');
      Future<void> capture(String stage) async {
        expect(tester.takeException(), isNull, reason: stage);
        if (!const bool.fromEnvironment('SIDEBAR_CAPTURE')) return;
        await tester.runAsync(() async {
          final image = await tester
              .renderObject<RenderRepaintBoundary>(find.byKey(root))
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final folder = Directory('../../.var/sidebar-review')
            ..createSync(recursive: true);
          await File('${folder.path}/${size.width.toInt()}-$stage.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
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
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/avatars/account.png'),
          tester.element(find.byType(PillxaiApp)),
        ),
      );
      await tester.pumpAndSettle();
      final sidebar = find.byKey(const ValueKey('workspace-sidebar'));
      expect(find.byKey(const ValueKey('nav-2')), findsNothing);
      expect(find.text('设置'), findsNothing);
      await capture('initial');
      await tester.tap(find.byKey(const ValueKey('account-menu')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(MenuItemButton, '设置'), findsOneWidget);
      expect(find.widgetWithText(MenuItemButton, '退出当前用户'), findsOneWidget);
      await capture('account-menu');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(MenuItemButton, '设置'), findsNothing);

      if (size.width >= 600) {
        await tester.tap(find.byKey(const ValueKey('toggle-sidebar')));
        await tester.pumpAndSettle();
      }
      expect(tester.getSize(sidebar).width, 76);
      expect(
        find.descendant(of: sidebar, matching: find.text('摆药')),
        findsNothing,
      );
      expect(
        find.descendant(of: sidebar, matching: find.text('处方管理')),
        findsNothing,
      );
      expect(find.byTooltip('展开侧栏'), findsOneWidget);
      await capture('collapsed');
      await openSettings(tester);
      expect(tester.getSize(sidebar).width, 76);
      expect(find.byKey(const ValueKey('page-title-settings')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('settings-search')),
        '准备',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('toggle-sidebar')));
      await tester.pumpAndSettle();
      expect(tester.getSize(sidebar).width, 232);
      expect(find.byTooltip('收起侧栏'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('settings-search')))
            .controller!
            .text,
        '准备',
      );
      await capture('expanded-settings');
      await tester.tap(find.byKey(const ValueKey('nav-0')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('page-title-prescriptions')),
        findsOneWidget,
      );
      if (size.width >= 600) {
        await tester.tap(find.byKey(const ValueKey('toggle-sidebar')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('page-title-dispensing')),
        findsOneWidget,
      );
      expect(tester.getSize(sidebar).width, 76);
      await capture('returned');
    });
  }
}

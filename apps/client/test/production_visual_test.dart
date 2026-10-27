import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_client/data/terminal_controller.dart';
import 'package:pillxai_client/data/settings_controller.dart';
import 'package:pillxai_client/data/prescription_repository.dart';
import 'package:pillxai_client/models/prescription_controller.dart';
import 'package:pillxai_client/screens/terminal_execution_panel.dart';
import 'package:pillxai_client/screens/plan_preview_page.dart';
import 'package:pillxai_client/theme/app_theme.dart';
import 'package:pillxai_client/widgets/workspace_sidebar.dart';
import 'package:pillxai_client/theme/app_page.dart';

import 'terminal_ui_test.dart' show FakeHost, snapshot;
import 'connected_prescriptions_test.dart' show connection, jsonResponse;
import 'server_planning_test.dart' show settingsJson;

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
  for (final size in [
    const Size(1280, 800),
    const Size(1024, 600),
    const Size(768, 1173),
    const Size(390, 844),
  ]) {
    testWidgets('production queue and live execution layout $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var failed = false;
      final backend =
          connection((request) async {
              if (request.url.path == '/preparation') {
                if (failed) {
                  return jsonResponse({
                    'code': 'offline',
                    'message': '清单读取失败',
                  }, 503);
                }
                return jsonResponse([
                  {
                    'resident_id': 'resident',
                    'name': '杨奶奶',
                    'bed': '601',
                    'early': false,
                    'medicine_count': 3,
                    'dates': ['2026-10-27', '2026-11-02'],
                  },
                  {
                    'resident_id': 'other',
                    'name': '测试长者',
                    'bed': '602',
                    'early': true,
                    'medicine_count': 1,
                    'dates': ['2026-11-03'],
                  },
                ]);
              }
              return jsonResponse([]);
            })
            ..settings = api.AppSettings.fromJson(settingsJson)
            ..account = api.AccountView(
              id: 'owner',
              username: 'admin',
              displayName: '管理员',
              role: api.Role.admin,
              canMaintain: true,
              active: true,
              revision: 1,
            );
      final host = FakeHost(snapshot());
      (host.value['task'] as Map)['plan']['resident_name'] = '杨奶奶';
      (host.value['task'] as Map)['plan']['bed'] = '601';
      (host.value['task'] as Map)['device']['configuration']['mode'] =
          'hardware';
      final terminal = TerminalController(backend, host);
      await terminal.initialize();
      final settings = SettingsController(backend, onSaved: () {});
      final residents = PrescriptionController(
        PrescriptionRepository(backend),
        bedtime: false,
        canEdit: true,
      );
      addTearDown(host.close);
      addTearDown(settings.dispose);
      addTearDown(residents.dispose);
      addTearDown(backend.dispose);
      const captureKey = ValueKey('production-capture');
      Widget shell(Widget body, String title) => RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          theme: createTheme(),
          home: Scaffold(
            body: Row(
              children: [
                WorkspaceSidebar(
                  selected: 1,
                  compact: size.width < 600,
                  onSelect: (_) {},
                  onSignOut: () {},
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        child: PageTitle(title),
                      ),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      Future<void> capture(String stage) async {
        if (!const bool.fromEnvironment('PRODUCTION_CAPTURE')) return;
        await tester.runAsync(() async {
          final image = await tester
              .renderObject<RenderRepaintBoundary>(find.byKey(captureKey))
              .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final folder = Directory('../../.tools/ui-review')
            ..createSync(recursive: true);
          await File(
            '${folder.path}/production-${size.width.toInt()}-$stage.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.pumpWidget(
        shell(
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: TerminalExecutionPanel(terminal: terminal),
          ),
          '正在分药',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('已摆 7 / 14 颗'), findsOneWidget);
      expect(find.text('杨奶奶'), findsOneWidget);
      await capture('running');
      await tester.ensureVisible(find.text('暂停'));
      await tester.tap(find.text('暂停'));
      await tester.pumpAndSettle();
      expect(host.operations, contains('pause'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        shell(
          PlanPreviewPage(
            backend: backend,
            residents: residents,
            settings: settings,
          ),
          '摆药',
        ),
      );
      await tester.pumpAndSettle();
      await capture('queue');
      expect(find.text('杨奶奶'), findsOneWidget);
      await tester.tap(find.text('提前准备 1'));
      await tester.pumpAndSettle();
      expect(find.text('测试长者'), findsOneWidget);
      expect(find.text('杨奶奶'), findsNothing);
      await tester.enterText(find.byType(TextField), '不存在');
      await tester.pumpAndSettle();
      expect(find.text('没有找到匹配的长者'), findsOneWidget);
      failed = true;
      await tester.tap(find.byTooltip('刷新待摆清单'));
      await tester.pumpAndSettle();
      expect(find.text('清单读取失败'), findsOneWidget);
      expect(find.text('提前准备 0'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      terminal.dispose();
    });
  }
}

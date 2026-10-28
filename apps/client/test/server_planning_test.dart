import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_client/data/prescription_repository.dart';
import 'package:pillxai_client/data/settings_controller.dart';
import 'package:pillxai_client/models/prescription_controller.dart';
import 'package:pillxai_client/screens/plan_preview_page.dart';
import 'package:pillxai_client/screens/settings_page.dart';
import 'package:pillxai_client/theme/app_theme.dart';

import 'connected_prescriptions_test.dart'
    show connection, jsonResponse, profile, residentId, actorId;

final settingsJson = <String, dynamic>{
  'timezone': 'Asia/Shanghai',
  'bedtime_enabled': false,
  'preparation_days': 7,
  'split_meals': true,
  'start_tomorrow': false,
  'revision': 1,
};
final prescription = {
  'id': actorId,
  'resident_id': residentId,
  'medicine_id': actorId,
  'revision': 1,
  'updated_at': '2026-10-26T08:00:00Z',
  'updated_by': actorId,
  'data': {
    'medicine_name': '接口快照药物',
    'strength': '10 mg',
    'unit': 'tablet',
    'feed_form': 'half',
    'doses': {'morning': '0.5', 'noon': '0', 'evening': '0', 'night': '0'},
    'meal_relation': 'after',
    'start_date': '2026-10-26',
    'end_date': null,
    'stopped': false,
  },
};
// Deliberately distinct from the source doses: the renderer must obey the supplied matrix.
Map<String, dynamic> previewJson({bool current = true}) => {
  'current': current,
  'message': current ? '预览未执行，不产生已摆药覆盖。' : '设置已变化，请重新生成。',
  'snapshot': {
    'id': actorId,
    'resident_id': residentId,
    'resident_revision': 1,
    'resident_name': '服务端长者',
    'bed': 'A-1',
    'business_date': '2026-10-26',
    'created_at': '2026-10-26T08:00:00Z',
    'settings': settingsJson,
    'requested_days': 7,
    'split_meals': true,
    'dates': ['2026-10-26'],
    'slots': ['早', '午', '晚'],
    'sources': [prescription],
    'trays': [
      {
        'purpose': '饭后、随餐及无餐食限制',
        'medicines': [
          {
            'prescription': prescription,
            'particles': [
              [25, 0, 0, 0],
            ],
            'total_particles': 25,
            'original_units': '12.5',
          },
        ],
      },
    ],
  },
};

void main() {
  testWidgets('设置异步保存、冲突草稿和重新加载', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pending = Completer<http.Response>();
    final writes = <Map<String, dynamic>>[];
    var saved = Map<String, dynamic>.from(settingsJson);
    final backend = connection((request) async {
      if (request.method == 'GET') return jsonResponse(saved);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      writes.add(body);
      if (writes.length == 1) return pending.future;
      saved = {...settingsJson, ...body, 'revision': 2}
        ..remove('expected_revision');
      return jsonResponse(saved);
    });
    backend.settings = api.AppSettings.fromJson(settingsJson)!;
    backend.account = api.AccountView(
      id: actorId,
      username: 'admin',
      displayName: '管理员',
      role: api.Role.admin,
      canMaintain: true,
      active: true,
      revision: 1,
    );
    var accepted = 0;
    final model = SettingsController(backend, onSaved: () => accepted++);
    addTearDown(model.dispose);
    addTearDown(backend.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: createTheme(accent: Colors.black),
        home: Scaffold(
          body: SettingsPage(
            model: model,
            accent: Colors.black,
            onAccentChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(find.text('保存中…'), findsOneWidget);
    expect(model.startTomorrow, isTrue);
    expect(model.canSaveRules, isFalse);
    expect(writes.single['expected_revision'], 1);
    pending.complete(
      jsonResponse({'code': 'revision_conflict', 'message': '设置版本冲突'}, 409),
    );
    await tester.pumpAndSettle();
    expect(find.text('设置版本冲突'), findsOneWidget);
    expect(find.text('设置已保存'), findsNothing);
    expect(model.startTomorrow, isTrue);
    expect(backend.settings!.startTomorrow, isFalse);
    await tester.tap(find.text('放弃更改并重新加载'));
    await tester.pumpAndSettle();
    expect(model.startTomorrow, isFalse);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.text('设置已保存'), findsOneWidget);
    expect(backend.settings!.revision, 2);
    expect(accepted, 2);
    final reopened = SettingsController(backend, onSaved: () {});
    await reopened.reloadSettings();
    expect(reopened.startTomorrow, isTrue);
    reopened.dispose();
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(1280, 800), const Size(390, 844)]) {
    testWidgets('服务端计划、数量图案、过期与失败提示 $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <Map<String, dynamic>>[];
      var failed = false;
      final backend = connection((request) async {
        if (request.url.path == '/preparation') {
          return jsonResponse([
            {
              'resident_id': residentId,
              'name': '服务端长者',
              'bed': 'A-1',
              'early': false,
              'medicine_count': 1,
              'dates': ['2026-10-26'],
            },
          ]);
        }
        if (request.method == 'POST') {
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (failed) {
            return jsonResponse({
              'code': 'no_demand',
              'message': '当前没有需要准备的用药。',
            }, 422);
          }
        }
        return jsonResponse(previewJson());
      });
      backend.settings = api.AppSettings.fromJson(settingsJson)!;
      final settings = SettingsController(backend, onSaved: () {});
      final residents = PrescriptionController(
        PrescriptionRepository(backend),
        bedtime: false,
        canEdit: true,
      );
      residents.residents.add(
        residentFromApi(api.ResidentView.fromJson(profile)!),
      );
      addTearDown(settings.dispose);
      addTearDown(residents.dispose);
      addTearDown(backend.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: createTheme(accent: Colors.black),
          home: Scaffold(
            body: PlanPreviewPage(
              backend: backend,
              residents: residents,
              settings: settings,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('开始摆药'));
      await tester.pumpAndSettle();
      expect(find.textContaining('25 颗 · 原片／粒等价量 12.5'), findsOneWidget);
      expect(
        find.text('准备药盒'),
        findsNothing,
      ); // Web preview has no machine controls.
      await tester.tap(find.text('预览摆药图案'));
      await tester.pumpAndSettle();
      expect(find.text('25颗\n点击查看'), findsOneWidget);
      await tester.tap(find.text('25颗\n点击查看'));
      await tester.pumpAndSettle();
      expect(find.textContaining('接口快照药物 25颗'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(FilledButton, '关闭'));
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsNothing);
      expect(find.text('餐食分盘  已开启'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('plan-days')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 天').last);
      await tester.pumpAndSettle();
      expect(requests.last['days'], 2);
      expect(requests.last['split_meals'], isNull);
      residents.updateBedtime(true);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '预览摆药图案'))
            .onPressed,
        isNull,
      );
      failed = true;
      await tester.tap(find.text('刷新计划'));
      await tester.pumpAndSettle();
      expect(find.text('当前没有需要准备的用药。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

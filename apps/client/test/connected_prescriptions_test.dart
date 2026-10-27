import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_client/data/backend_connection.dart';
import 'package:pillxai_client/data/terminal_host_stub.dart';
import 'package:pillxai_client/data/prescription_repository.dart';
import 'package:pillxai_client/models/prescription_controller.dart';
import 'package:pillxai_client/models/prescription_store.dart';
import 'package:pillxai_client/screens/connected_workspace.dart';
import 'package:pillxai_client/widgets/prescription_forms.dart';

const residentId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const actorId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
final profile = {
  'id': residentId,
  'revision': 1,
  'data': {'name': '服务端长者', 'bed': 'A-1'},
  'updated_at': '2026-10-26T08:00:00Z',
  'updated_by': actorId,
};

BackendConnection connection(
  Future<http.Response> Function(http.Request) respond,
) {
  final client = api.ApiClient(basePath: 'http://localhost:8000');
  client.client.close();
  client.client = MockClient(respond);
  return BackendConnection(client: client);
}

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  testWidgets('服务端冲突保留表单草稿，等待保存时不能重复发送', (tester) async {
    final response = Completer<http.Response>();
    var writes = 0;
    final backend = connection((request) async {
      if (request.method == 'PUT') {
        writes++;
        return response.future;
      }
      return jsonResponse({
        'items': [profile],
        'next_after': null,
      });
    });
    final store = PrescriptionController(
      PrescriptionRepository(backend),
      bedtime: false,
      canEdit: true,
    );
    addTearDown(store.dispose);
    addTearDown(backend.dispose);
    final resident = residentFromApi(api.ResidentView.fromJson(profile)!);
    store.residents.add(resident);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResidentForm(
            model: store,
            resident: resident,
            onSave: store.saveResident,
          ),
        ),
      ),
    );
    await tester.enterText(field('姓名'), '保留这份草稿');
    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(find.text('保存中…'), findsOneWidget);
    expect(writes, 1);
    response.complete(
      jsonResponse({
        'code': 'revision_conflict',
        'message': '资料已变化，请刷新后重新核对；当前草稿未保存。',
      }, 409),
    );
    await tester.pumpAndSettle();
    expect(find.text('保留这份草稿'), findsOneWidget);
    expect(find.textContaining('当前草稿未保存'), findsOneWidget);
    expect(store.residents.single.name, '服务端长者');
    expect(writes, 1);
    expect(tester.takeException(), isNull);
  });

  test('刷新失败不能变成空名单；迟到的选择响应不能污染当前长者', () async {
    final slow = Completer<http.Response>();
    var fail = false;
    final otherId = newRecordId();
    final backend = connection((request) async {
      if (fail) {
        return jsonResponse({'code': 'unavailable', 'message': '加载失败'}, 503);
      }
      if (request.url.path.endsWith('/residents')) {
        return jsonResponse({
          'items': [profile],
          'next_after': null,
        });
      }
      if (request.url.path.contains(otherId)) return slow.future;
      return jsonResponse([]);
    });
    final store = PrescriptionController(
      PrescriptionRepository(backend),
      bedtime: false,
      canEdit: true,
    );
    addTearDown(store.dispose);
    addTearDown(backend.dispose);
    await store.refresh();
    expect(store.residents.single.name, '服务端长者');
    store.residents.add(
      Resident(id: otherId, name: '另一位', bed: '', medicines: []),
    );
    store.selectResident(otherId);
    store.selectResident(residentId);
    await Future<void>.delayed(Duration.zero);
    slow.complete(jsonResponse([]));
    await Future<void>.delayed(Duration.zero);
    expect(store.selectedResidentId, residentId);
    expect(store.loading, isFalse);
    fail = true;
    await store.refresh();
    expect(store.error, contains('加载失败'));
    expect(store.residents, isNotEmpty);
  });

  for (final size in [const Size(1280, 800), const Size(390, 844)]) {
    testWidgets('真实登录入口与只读权限在 $size 可用，生产页面无演示长者', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final backend = connection((request) async {
        if (request.url.path == '/auth/login') {
          return jsonResponse({
            'access_token': 'fixture-token',
            'expires_at': '2026-10-27T00:00:00Z',
            'account': {
              'id': actorId,
              'username': 'staff',
              'display_name': '测试员工',
              'role': 'staff',
              'can_maintain': false,
              'active': true,
              'revision': 1,
            },
          });
        }
        expect(request.headers['Authorization'], 'Bearer fixture-token');
        if (request.url.path == '/settings') {
          return jsonResponse({
            'timezone': 'Asia/Shanghai',
            'bedtime_enabled': false,
            'preparation_days': 7,
            'split_meals': true,
            'start_tomorrow': false,
            'revision': 1,
          });
        }
        if (request.url.path.endsWith('/residents')) {
          return jsonResponse({
            'items': [profile],
            'next_after': null,
          });
        }
        return jsonResponse([]);
      });
      addTearDown(backend.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ConnectedWorkspace(
            terminalHost: UnavailableTerminalHost(),
            backend: backend,
            accent: Colors.black,
            onAccentChanged: (_) {},
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-account')),
        'staff',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'password',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('login-submit')));
      await tester.tap(find.byKey(const ValueKey('login-submit')));
      await tester.pumpAndSettle();
      expect(find.text('服务端长者'), findsWidgets);
      expect(find.text('当前机构'), findsNothing);
      expect(find.text('王奶奶'), findsNothing);
      final add = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '添加长者'),
      );
      expect(add.onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      expect(find.text('预览计划'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav-2')));
      await tester.pumpAndSettle();
      expect(find.text('创建机构'), findsNothing);
      expect(find.text('账号管理'), findsNothing);
      expect(find.text('修改本人密码'), findsNothing);
      expect(find.byKey(const ValueKey('page-title-settings')), findsOneWidget);
      expect(find.text('设置'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('settings-search')), findsOneWidget);
      expect(find.text('准备周期'), findsOneWidget);
      expect(find.text('药盒布局'), findsOneWidget);
      expect(
        tester
            .widgetList<Switch>(find.byType(Switch))
            .every((control) => control.onChanged == null),
        isTrue,
      );
      await tester.enterText(
        find.byKey(const ValueKey('settings-search')),
        '颜色',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('custom-accent-input')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('settings-search')),
        '检查更新',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('check-for-updates')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

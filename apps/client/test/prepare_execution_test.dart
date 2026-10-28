import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_client/data/terminal_controller.dart';
import 'package:pillxai_client/screens/prepare_execution_dialog.dart';

import 'connected_prescriptions_test.dart' show connection, jsonResponse, field;
import 'server_planning_test.dart' show previewJson;
import 'terminal_ui_test.dart' show FakeHost;

void main() {
  test('SDK accepts absent parameters and reads saved parameters', () async {
    final saved = api.ParameterView(
      prescriptionId: 'prescription',
      medicineId: 'medicine',
      revision: 1,
      turntable: 1,
      gate: 0.5,
      simulationOnly: true,
    );
    var hasParameters = false;
    final backend = connection(
      (_) async => hasParameters
          ? jsonResponse(saved.toJson())
          : http.Response('null', 200),
    );
    addTearDown(backend.dispose);
    final execution = api.ExecutionApi(backend.client);
    expect(
      await backend.request(
        execution.getParameters('resident', 'prescription'),
      ),
      isNull,
    );
    hasParameters = true;
    expect(
      await backend.request(
        execution.getParameters('resident', 'prescription'),
      ),
      saved,
    );
  });

  testWidgets(
    'new prescription can load preparation and bind a label without parameters',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final plan = api.PlanSnapshot.fromJson(previewJson()['snapshot'])!;
      final labels = <Map<String, dynamic>>[];
      final backend =
          connection((request) async {
              if (request.url.path == '/residents/${plan.residentId}') {
                return jsonResponse({
                  'id': plan.residentId,
                  'revision': 1,
                  'data': {'name': plan.residentName, 'bed': '', 'barcode': ''},
                  'updated_at': '2026-10-27T08:00:00Z',
                  'updated_by': 'owner',
                });
              }
              if (request.url.path.endsWith('/parameters')) {
                return http.Response('null', 200);
              }
              expect(request.url.path, '/residents/${plan.residentId}/labels');
              if (request.method == 'POST') {
                labels.add({
                  'uid': jsonDecode(request.body)['uid'],
                  'resident_id': plan.residentId,
                });
                return jsonResponse(labels.single);
              }
              return jsonResponse(labels);
            })
            ..account = api.AccountView(
              id: 'admin',
              username: 'tester',
              displayName: '测试管理员',
              role: api.Role.admin,
              canMaintain: true,
              active: true,
              revision: 1,
            );
      final host = FakeHost({});
      final terminal = TerminalController(backend, host)
        ..view = {
          'state': {'phase': 'idle', 'connected': true},
          'observed_uid': 'AABB1234',
          'observed_at': DateTime.now().toUtc().toIso8601String(),
        };
      addTearDown(terminal.dispose);
      addTearDown(backend.dispose);
      addTearDown(host.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrepareExecutionDialog(terminal: terminal, plan: plan),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('无法连接服务器'), findsNothing);
      await tester.tap(find.text('药盒与出药设置'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field('转盘初速度')).controller!.text, '0.2');
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '开仓放入药盒'))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('填入最近读取的标签'));
      await tester.tap(find.text('绑定到当前长者'));
      await tester.pumpAndSettle();
      expect(find.text('已设置药盒识别'), findsOneWidget);
      expect(labels.single['resident_id'], plan.residentId);
      expect(host.operations, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scenario in ['default', 'disable-new', 'disable-existing']) {
    testWidgets('preparation preserves parameter policy: $scenario', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final plan = api.PlanSnapshot.fromJson(previewJson()['snapshot'])!;
      final source = plan.trays.first.medicines.first.prescription;
      final saved = scenario == 'disable-existing'
          ? api.ParameterView(
              prescriptionId: source.id,
              medicineId: source.medicineId,
              revision: 1,
              turntable: 0.31,
              gate: 0.83,
              feedForm: 'half',
            )
          : null;
      final writes = <Map<String, dynamic>>[];
      final backend =
          connection((request) async {
              if (request.url.path.endsWith('/labels')) {
                return jsonResponse([
                  {'uid': 'AABB1234', 'resident_id': plan.residentId},
                ]);
              }
              if (request.url.path == '/residents/${plan.residentId}') {
                return jsonResponse({
                  'id': plan.residentId,
                  'revision': 1,
                  'data': {'name': plan.residentName, 'bed': '', 'barcode': ''},
                  'updated_at': '2026-10-27T08:00:00Z',
                  'updated_by': 'owner',
                });
              }
              if (request.url.path.endsWith('/parameters')) {
                if (request.method == 'GET') {
                  return saved == null
                      ? http.Response('null', 200)
                      : jsonResponse(saved.toJson());
                }
                final body = jsonDecode(request.body) as Map<String, dynamic>;
                writes.add(body);
                return jsonResponse({
                  'prescription_id': source.id,
                  'revision': 2,
                  'feed_form': 'half',
                  ...body,
                });
              }
              return jsonResponse({'code': 'test', 'message': '测试结束'}, 409);
            })
            ..account = api.AccountView(
              id: 'admin',
              username: 'tester',
              displayName: '管理员',
              role: api.Role.admin,
              canMaintain: true,
              active: true,
              revision: 1,
            );
      final host = FakeHost({});
      final terminal = TerminalController(backend, host)
        ..view = {
          'state': {'phase': 'idle', 'connected': true},
          'terminal_id': 'terminal',
          'configuration': {'device_id': 'device'},
        }
        ..devices = [
          api.DeviceView(
            id: 'device',
            revision: 1,
            configuration: api.DeviceConfiguration(
              name: '测试机',
              identity: 'id',
              terminalId: 'terminal',
              mode: api.DeviceMode.hardware,
              rows: [2, 1, 0, 3],
            ),
          ),
        ];
      addTearDown(terminal.dispose);
      addTearDown(backend.dispose);
      addTearDown(host.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrepareExecutionDialog(terminal: terminal, plan: plan),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (scenario != 'default') {
        await tester.tap(find.text('药盒与出药设置'));
        await tester.pumpAndSettle();
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged!(
          false,
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('开仓放入药盒'));
      await tester.pumpAndSettle();
      if (scenario == 'default') {
        expect(
          writes,
          isEmpty,
          reason: 'default choice is not a learned or manual history',
        );
      } else {
        expect(writes.single['learning_enabled'], isFalse);
        expect(writes.single['has_values'], scenario == 'disable-existing');
        expect(
          writes.single['turntable'],
          scenario == 'disable-existing' ? 0.31 : 0.2,
        );
        expect(
          writes.single['gate'],
          scenario == 'disable-existing' ? 0.83 : 0.7,
        );
      }
      expect(host.operations, contains('claim_intent'));
      expect(host.operations, isNot(contains('attach')));
      expect(tester.takeException(), isNull);
    });
  }
}

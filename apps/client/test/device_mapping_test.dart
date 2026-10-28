import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_client/data/terminal_controller.dart';
import 'package:pillxai_client/screens/device_mapping_dialog.dart';

import 'connected_prescriptions_test.dart' show connection, jsonResponse;
import 'terminal_ui_test.dart' show FakeHost;

void main() {
  for (final size in [const Size(1280, 900), const Size(390, 844)]) {
    testWidgets(
      'mapping saves current device only and never sends machine commands $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final original = api.DeviceView(
          id: 'device01',
          revision: 3,
          configuration: api.DeviceConfiguration(
            name: 'PillDispenser01',
            identity: '00:25:11:01:13:92',
            terminalId: 'terminal',
            mode: api.DeviceMode.hardware,
            rows: [2, 1, 0, 3],
            positionsVerified: true,
            trayPresentLine: 'PRESENT',
            trayAbsentLine: 'ABSENT',
            readyLine: 'READY',
            feedbackVerified: true,
          ),
        );
        var writes = 0;
        final backend =
            connection((request) async {
                writes++;
                expect(request.method, 'PUT');
                expect(request.url.path, '/devices/device01');
                final body = jsonDecode(request.body);
                expect(body['expected_revision'], 3);
                expect(body['configuration']['rows'], [1, 2, 0, 3]);
                expect(body['configuration']['reverse_columns'], true);
                expect(body['configuration']['positions_verified'], true);
                expect(body['configuration']['tray_present_line'], 'PRESENT');
                expect(body['configuration']['feedback_verified'], true);
                return jsonResponse({
                  'id': original.id,
                  'revision': 4,
                  'configuration': body['configuration'],
                });
              })
              ..account = api.AccountView(
                id: 'owner',
                username: 'admin',
                displayName: '管理员',
                role: api.Role.admin,
                canMaintain: true,
                active: true,
                revision: 1,
              );
        final host = FakeHost({});
        final terminal = TerminalController(backend, host)
          ..devices = [original]
          ..view = {
            'configuration': {'device_id': original.id},
            'state': {'connected': true},
          };
        await tester.pumpWidget(
          MaterialApp(home: DeviceMappingDialog(terminal: terminal)),
        );
        final morning = find.byKey(const ValueKey('早-2'));
        await tester.tap(
          find.descendant(of: morning, matching: find.byType(OutlinedButton)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(MenuItemButton, '第 1 行'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          false,
        );
        expect(find.byKey(const ValueKey('午-2')), findsOneWidget);
        await tester.ensureVisible(find.byType(SwitchListTile));
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        await tester.tap(find.text('保存映射'));
        await tester.pumpAndSettle();
        expect(writes, 1);
        expect(terminal.device!.configuration.rows, [1, 2, 0, 3]);
        expect(terminal.connected, true);
        expect(host.operations, isEmpty);
        expect(find.text('映射已保存'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(home: DeviceMappingDialog(terminal: terminal)),
        );
        expect(find.byKey(const ValueKey('早-1')), findsOneWidget);
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          true,
        );
        terminal.view['claim_intent'] = {'pending': true};
        await expectLater(
          terminal.savePositionMapping(
            terminal.device!,
            rows: [2, 1, 0, 3],
            reverseColumns: false,
            verified: false,
          ),
          throwsA(isA<Exception>()),
        );
        expect(writes, 1);
        await tester.pumpWidget(const SizedBox());
        terminal.dispose();
        await host.close();
        backend.dispose();
      },
    );
  }
}

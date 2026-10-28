import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_client/data/terminal_controller.dart';
import 'package:pillxai_client/screens/terminal_device_dialog.dart';

import 'connected_prescriptions_test.dart' show connection, jsonResponse;
import 'terminal_ui_test.dart' show FakeHost;

class ConnectionHost extends FakeHost {
  ConnectionHost(super.value);
  Map<String, dynamic>? connectedConfiguration;
  bool failPair = false;
  @override
  Future<dynamic> command(
    String operation, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (operation == 'discover_devices') {
      operations.add(operation);
      return [
        {
          'address': 'AA:BB:CC:DD:EE:FF',
          'name': 'PillDispenser03',
          'paired': false,
        },
      ];
    }
    if (operation == 'pair_device' && failPair) {
      operations.add(operation);
      throw StateError('配对未完成');
    }
    if (operation == 'configure') {
      value['configuration'] = data;
      events.add(value);
    }
    if (operation == 'connect') {
      connectedConfiguration = Map<String, dynamic>.from(
        value['configuration'] as Map,
      );
    }
    return super.command(operation, data);
  }
}

void main() {
  for (final failure in ['none', 'pair', 'save']) {
    testWidgets('add unpaired device pairs, persists and connects: $failure', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final devices = <Map<String, dynamic>>[];
      final order = <String>[];
      final backend =
          connection((request) async {
              if (request.method == 'PUT') {
                order.add('save');
                if (failure == 'save') {
                  return jsonResponse({
                    'code': 'conflict',
                    'message': '保存失败',
                  }, 409);
                }
                final body = jsonDecode(request.body) as Map;
                expect(body['configuration']['identity'], 'AA:BB:CC:DD:EE:FF');
                expect(body['configuration']['positions_verified'], false);
                devices.add({
                  'id': request.url.pathSegments.last,
                  'revision': 1,
                  'configuration': body['configuration'],
                });
                return jsonResponse(devices.last);
              }
              return jsonResponse(devices);
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
      final host = ConnectionHost({
        'platform': 'android',
        'terminal_id': 'terminal',
        'state': {'connected': false, 'phase': 'idle'},
      })..failPair = failure == 'pair';
      final terminal = TerminalController(backend, host);
      await terminal.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TerminalDeviceDialog(terminal: terminal)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-device')));
      await tester.pumpAndSettle();
      expect(find.text('未配对'), findsOneWidget);
      expect(find.text('AA:BB:CC:DD:EE:FF'), findsNothing);
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      expect(host.operations, contains('pair_device'));
      if (failure == 'none') {
        expect(
          host.operations.indexOf('pair_device'),
          lessThan(host.operations.indexOf('configure')),
        );
        expect(
          host.operations.indexOf('configure'),
          lessThan(host.operations.indexOf('connect')),
        );
        expect(host.connectedConfiguration?['port'], 'AA:BB:CC:DD:EE:FF');
        expect(find.text('我的设备'), findsOneWidget);
        expect(find.text('设备诊断'), findsNothing);
      } else {
        expect(host.operations, isNot(contains('connect')));
        expect(host.operations, isNot(contains('configure')));
        if (failure == 'pair') expect(order, isEmpty);
      }
      await tester.pumpWidget(const SizedBox());
      terminal.dispose();
      await host.close();
      backend.dispose();
    });
  }
  for (final failSave in [false, true]) {
    testWidgets(
      'paired selection saves new identity before connecting; failure=$failSave',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final old = api.DeviceView.fromJson({
          'id': 'old-device',
          'revision': 1,
          'configuration': {
            'name': 'PillDispenser02',
            'identity': '00:25:04:01:24:B5',
            'terminal_id': 'terminal',
            'mode': 'hardware',
            'rows': [2, 1, 0, 3],
            'positions_verified': true,
            'feedback_verified': true,
          },
        })!;
        final devices = [old];
        var saves = 0;
        final backend =
            connection((request) async {
                if (request.method == 'PUT') {
                  saves++;
                  expect(request.url.path, isNot('/devices/old-device'));
                  final body = jsonDecode(request.body) as Map;
                  expect(body['expected_revision'], 0);
                  expect(
                    body['configuration']['identity'],
                    'AA:BB:CC:DD:EE:FF',
                  );
                  expect(body['configuration']['positions_verified'], false);
                  expect(body['configuration']['feedback_verified'], false);
                  if (failSave) {
                    return jsonResponse({
                      'code': 'conflict',
                      'message': '保存失败',
                    }, 409);
                  }
                  final saved = api.DeviceView.fromJson({
                    'id': request.url.pathSegments.last,
                    'revision': 1,
                    'configuration': body['configuration'],
                  })!;
                  devices.add(saved);
                  return jsonResponse(saved.toJson());
                }
                return jsonResponse(devices.map((d) => d.toJson()).toList());
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
        final host = ConnectionHost({
          'platform': 'android',
          'terminal_id': 'terminal',
          'state': {'connected': false, 'phase': 'idle'},
          'configuration': {
            'device_id': old.id,
            'mode': 'hardware',
            'port': old.configuration.identity,
          },
        });
        final terminal = TerminalController(backend, host);
        await terminal.initialize();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: TerminalDeviceDialog(terminal: terminal)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('配置设备'));
        await tester.pumpAndSettle();
        final paired = find.byKey(const ValueKey('paired-devices'));
        await tester.ensureVisible(paired);
        await tester.tap(paired);
        await tester.pumpAndSettle();
        await tester.tap(find.text('dispenser01 · AA:BB:CC:DD:EE:FF').last);
        await tester.pumpAndSettle();
        final connect = find.text('保存并连接');
        await tester.ensureVisible(connect);
        await tester.tap(connect);
        await tester.pumpAndSettle();
        expect(saves, 1);
        if (failSave) {
          expect(host.operations, isNot(contains('connect')));
          expect(host.operations, isNot(contains('configure')));
        } else {
          expect(host.connectedConfiguration?['port'], 'AA:BB:CC:DD:EE:FF');
          expect(
            host.operations.indexOf('configure'),
            lessThan(host.operations.indexOf('connect')),
          );
          expect(old.configuration.identity, '00:25:04:01:24:B5');
        }
        await tester.pumpWidget(const SizedBox());
        terminal.dispose();
        await host.close();
        backend.dispose();
      },
    );
  }
}

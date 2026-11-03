import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_client/data/backend_connection.dart';
import 'package:pillxai_client/data/terminal_controller.dart';
import 'package:pillxai_client/screens/terminal_execution_panel.dart';
import 'package:pillxai_client/theme/app_theme.dart';

import 'terminal_ui_test.dart' show FakeHost, snapshot;

class SkipHost extends FakeHost {
  SkipHost(super.value);
  bool wasRunning = false;
  Map<String, dynamic>? submitted;
  @override
  Future<dynamic> command(
    String operation, [
    Map<String, dynamic> data = const {},
  ]) async {
    final state = value['state'] as Map;
    if (operation == 'review_skip') {
      wasRunning = state['phase'] == 'running';
      state['phase'] = 'reviewingSkip';
    }
    if (operation == 'cancel_skip') {
      state['phase'] = wasRunning ? 'running' : 'paused';
    }
    if (operation == 'skip') {
      submitted = data;
      state['phase'] = 'skipping';
    }
    events.add(value);
    return super.command(operation, data);
  }
}

void main() {
  setUpAll(() async {
    await (FontLoader('NotoSansSC')
          ..addFont(rootBundle.load('assets/fonts/NotoSansCJKsc-Regular.otf')))
        .load();
  });
  for (final width in [390.0, 1280.0]) {
    for (final paused in [false, true]) {
      testWidgets(
        'skip dialog cancels to prior state, defaults unchecked, width=$width paused=$paused',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final client = api.ApiClient(basePath: 'http://localhost');
          client.client.close();
          client.client = MockClient((_) async => http.Response('[]', 200));
          final backend = BackendConnection(client: client)
            ..account = api.AccountView(
              id: 'owner',
              username: 'tester',
              displayName: '测试',
              role: api.Role.admin,
              canMaintain: true,
              active: true,
              revision: 1,
            );
          final data = snapshot();
          (data['task'] as Map)['skip_protocol'] = 1;
          (data['state'] as Map)['phase'] = paused ? 'paused' : 'running';
          final host = SkipHost(data);
          final terminal = TerminalController(backend, host);
          await terminal.initialize();
          const capture = ValueKey('skip-capture');
          await tester.pumpWidget(
            RepaintBoundary(
              key: capture,
              child: MaterialApp(
                theme: createTheme(),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: TerminalExecutionPanel(terminal: terminal),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byKey(const ValueKey('skip-medicine')),
          );
          await tester.tap(find.byKey(const ValueKey('skip-medicine')));
          await tester.pumpAndSettle();
          expect(host.operations, contains('review_skip'));
          expect(
            tester
                .widget<CheckboxListTile>(find.byType(CheckboxListTile))
                .value,
            isFalse,
          );
          expect(tester.takeException(), isNull);
          if (!paused) {
            await tester.runAsync(() async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(capture),
              );
              final picture = await boundary.toImage();
              final bytes = await picture.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final path = File(
                '../../.tools/ui-review/skip-${width.toInt()}.png',
              );
              path.parent.createSync(recursive: true);
              path.writeAsBytesSync(bytes!.buffer.asUint8List());
              picture.dispose();
            });
          }
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          expect(terminal.phase, paused ? 'paused' : 'running');
          expect(host.submitted, isNull);
          await tester.tap(find.byKey(const ValueKey('skip-medicine')));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(CheckboxListTile));
          await tester.pumpAndSettle();
          await tester.tap(find.text(paused ? '确认跳过' : '跳过该长者所有剩余药物'));
          await tester.pumpAndSettle();
          expect(host.submitted, {
            'task_id': 'task',
            'batch': 0,
            'all_remaining': !paused,
            'manual': paused,
          });
          expect(find.byType(AlertDialog), findsNothing);
          await tester.pumpWidget(const SizedBox());
          terminal.dispose();
          unawaited(host.close());
          backend.dispose();
        },
      );
    }
  }
}

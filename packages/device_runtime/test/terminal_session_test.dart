import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_device_runtime/device_runtime.dart';
import 'package:test/test.dart';

import 'support/task_fixture.dart';

void main() {
  test('shared host persists configuration, protects ambiguous claim and survives rejected commands', () async {
    final dir = Directory.systemTemp.createTempSync('pillxai-session-');
    final journal = ExecutionJournal('${dir.path}/execution.sqlite');
    final session = TerminalSession(
      journal: journal,
      platform: 'android',
      ports: () => [],
      publish: (_) {},
      hardwareTransport: (_) => throw UnimplementedError(),
    );
    try {
      await expectLater(session.command('unknown'), throwsArgumentError);
      await session.command('configure', {
        'mode': 'simulator',
        'uid': 'A1B2C3D4',
      });
      await session.command('claim_intent', {'id': 'uncertain'});
      await expectLater(session.command('configure'), throwsStateError);
      await expectLater(session.command('shutdown'), throwsStateError);
      expect((await session.command('view') as Map)['claim_intent'], {
        'id': 'uncertain',
      });
      await session.command('claim_intent');
      await session.command('shutdown');
      final reopened = ExecutionJournal('${dir.path}/execution.sqlite');
      expect((reopened.setting('connection') as Map)['mode'], 'simulator');
      reopened.close();
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test(
    'shared background session completes two trays without a UI listener',
    () async {
      final dir = Directory.systemTemp.createTempSync('pillxai-headless-');
      final journal = ExecutionJournal('${dir.path}/execution.sqlite');
      final session = TerminalSession(
        journal: journal,
        platform: 'android',
        ports: () => [],
        publish: (_) {},
        hardwareTransport: (_) => throw UnimplementedError(),
      );
      Future<Map> waitFor(bool Function(Map) condition) async {
        for (var attempt = 0; attempt < 150; attempt++) {
          final view = await session.command('view') as Map;
          if (condition(view)) return view;
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }
        throw StateError('Session timed out: ${await session.command('view')}');
      }

      session.start();
      await session.command('configure', {'mode': 'simulator'});
      await session.command('connect');
      final task = fixture(journal.terminalId);
      Map<String, dynamic> json(Object value) =>
          jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
      await session.command('attach', json(task));
      await waitFor((v) => v['state']['phase'] == 'ready');
      await session.command(
        'begin',
        json(task.copyWith(state: api.TaskState.started)),
      );
      await waitFor(
        (v) => v['state']['batch'] == 1 && v['state']['phase'] == 'ready',
      );
      await session.command('continue_tray');
      await waitFor((v) => v['state']['phase'] == 'collecting');
      await session.command('sim_remove');
      final completed = await waitFor(
        (v) => v['state']['phase'] == 'completed',
      );
      final events = await session.command('pending') as List;
      expect(events.where((e) => e['kind'] == 'batch_finished').length, 2);
      expect(completed['platform'], 'android');
      await session.command('acknowledge', {
        'sequence': completed['state']['sequence'],
      });
      await session.command('shutdown');
      dir.deleteSync(recursive: true);
    },
  );
}

import 'dart:io';

import 'package:pillxai_device_runtime/device_runtime.dart';
import 'package:pillxai_execution_core/execution_core.dart';
import 'package:test/test.dart';

import 'support/task_fixture.dart';

void main() {
  late Directory dir;
  late ExecutionJournal journal;
  late TerminalSession session;
  TerminalSession create() => TerminalSession(
    journal: journal,
    hardwareTransport: (_) => throw StateError('Unexpected hardware access'),
    ports: () => [],
    publish: (_) {},
    platform: 'android',
  );
  setUp(() {
    dir = Directory.systemTemp.createTempSync('pillxai-update-');
    journal = ExecutionJournal('${dir.path}/execution.sqlite');
    session = create();
  });
  tearDown(() {
    journal.close();
    dir.deleteSync(recursive: true);
  });

  test(
    'lock persists across restart and blocks all task/device entry points',
    () async {
      journal.setSetting('connection', {
        'mode': 'simulator',
        'uid': 'A1B2C3D4',
      });
      await session.command('update_lock', {'token': 'one'});
      journal.close();
      journal = ExecutionJournal('${dir.path}/execution.sqlite');
      session = create();
      expect(session.view()['update_lock'], 'one');
      for (final operation in [
        'connect',
        'claim_intent',
        'attach',
        'begin',
        'open_binding',
        'configure',
        'shutdown',
      ]) {
        await expectLater(session.command(operation), throwsStateError);
      }
      await expectLater(
        session.command('update_unlock', {'token': 'wrong'}),
        throwsStateError,
      );
      await session.command('update_unlock', {'token': 'one'});
      expect(journal.setting('connection'), isNotNull);
      await session.command('connect');
      expect(session.engine.state.connected, isTrue);
      await session.command('disconnect');
    },
  );

  test('queued claim wins before installation; no race window', () async {
    final claim = session.command('claim_intent', {'id': 'pending'});
    final install = session.command('update_lock', {'token': 'one'});
    await claim;
    await expectLater(install, throwsStateError);
    expect(journal.setting('update_lock'), isNull);
  });

  test('box still present prevents installation even in idle', () async {
    session.engine.state.trayPresent = true;
    await expectLater(
      session.command('update_lock', {'token': 'one'}),
      throwsStateError,
    );
    expect(journal.setting('update_lock'), isNull);
  });

  for (final phase in ExecutionPhase.values.where(
    (p) => p != ExecutionPhase.idle,
  )) {
    test('non-idle $phase cannot install even without a loaded task', () async {
      session.engine.state.phase = phase;
      await expectLater(
        session.command('update_lock', {'token': 'one'}),
        throwsStateError,
      );
    });
  }

  test(
    'unuploaded facts survive rejected install and database reopen',
    () async {
      final task = fixture(journal.terminalId);
      journal.save(
        task,
        ExecutionState()..phase = ExecutionPhase.completed,
        kind: 'finished',
      );
      await expectLater(
        session.command('update_lock', {'token': 'one'}),
        throwsStateError,
      );
      journal.close();
      journal = ExecutionJournal('${dir.path}/execution.sqlite');
      expect(journal.pending(task.id).single['kind'], 'finished');
      expect(journal.active(), isNotNull);
    },
  );
}

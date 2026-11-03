import 'dart:io';

import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_device_runtime/device_runtime.dart';
import 'package:pillxai_execution_core/execution_core.dart';
import 'package:test/test.dart';

import 'execution_test.dart' show until;
import 'support/task_fixture.dart';

void main() {
  late Directory dir;
  late ExecutionJournal journal;
  late ExecutionEngine engine;
  late MachineSimulator machine;
  setUp(() async {
    dir = Directory.systemTemp.createTempSync('pillxai-skip-');
    journal = ExecutionJournal('${dir.path}/state.db');
    engine = ExecutionEngine(
      journal,
      commandTimeout: const Duration(milliseconds: 100),
    );
    machine = MachineSimulator(interval: const Duration(hours: 1));
    await engine.connect(machine);
    final base = fixture(journal.terminalId, batches: 3);
    final task = base.copyWith(
      skipProtocol: 1,
      batches: [for (final batch in base.batches) batch.copyWith(tray: 0)],
    );
    await engine.attach(task);
    await until(engine, () => engine.state.phase == ExecutionPhase.ready);
    await engine.begin(task.copyWith(state: api.TaskState.started));
    await until(engine, () => engine.state.phase == ExecutionPhase.running);
    machine.emit('number:1,width:20');
    await engine.tick();
  });
  tearDown(() {
    journal.close();
    dir.deleteSync(recursive: true);
  });

  Future<void> review() async {
    await engine.reviewSkip(engine.task!.id, engine.state.batch);
    await engine.tick();
  }

  for (final paused in [false, true]) {
    test(
      'cancel restores prior pause=$paused without another matrix',
      () async {
        if (paused) {
          await engine.pause();
          await engine.tick();
        }
        await review();
        expect(machine.running, isFalse);
        await engine.cancelSkip(engine.task!.id, 0);
        await engine.tick();
        expect(
          engine.state.phase,
          paused ? ExecutionPhase.paused : ExecutionPhase.running,
        );
        expect(engine.state.count, 1);
        expect(machine.writes.where((b) => b[2] == 5), hasLength(1));
      },
    );
    test('skip advances once and preserves pause=$paused', () async {
      if (paused) {
        await engine.pause();
        await engine.tick();
      }
      await review();
      await engine.skip(engine.task!.id, 0, allRemaining: false, manual: false);
      await until(
        engine,
        () =>
            engine.state.phase ==
            (paused
                ? ExecutionPhase.awaitingNextBatch
                : ExecutionPhase.running),
      );
      expect(engine.state.batch, 1);
      expect(engine.task!.skippedBatches, [0]);
      final commands = machine.writes.map((b) => b[2]).toList();
      expect(commands.where((c) => c == 0), hasLength(1));
      expect(commands.where((c) => c == 5), hasLength(paused ? 1 : 2));
      await expectLater(
        engine.skip(engine.task!.id, 0, allRemaining: false, manual: false),
        throwsStateError,
      );
      if (paused) {
        await engine.beginNextBatch(engine.task!.id, 1);
        await until(engine, () => engine.state.phase == ExecutionPhase.running);
        expect(machine.writes.where((b) => b[2] == 5), hasLength(2));
      }
    });
  }
  test(
    'all remaining skips future trays without matrices; collects and persists',
    () async {
      await review();
      await engine.skip(engine.task!.id, 0, allRemaining: true, manual: false);
      await until(
        engine,
        () => engine.state.phase == ExecutionPhase.collecting,
      );
      expect(engine.task!.skippedBatches, [0, 1, 2]);
      expect(engine.state.count, 1);
      expect(machine.writes.where((b) => b[2] == 5), hasLength(1));
      final events = journal.pending(engine.task!.id);
      expect(events.where((e) => e['kind'] == 'batch_finished'), isEmpty);
      expect(events.where((e) => e['kind'] == 'skip_completed'), hasLength(1));
    },
  );
  test(
    'manual confirmation retains machine count and excludes machine finish',
    () async {
      await review();
      await engine.skip(engine.task!.id, 0, allRemaining: false, manual: true);
      await until(engine, () => engine.state.batch == 1);
      expect(engine.task!.manualBatches, [0]);
      final events = journal.pending(engine.task!.id);
      expect(
        events.where((e) => e['kind'] == 'count').last['detail'],
        containsPair('count', 1),
      );
      expect(events.where((e) => e['kind'] == 'batch_finished'), isEmpty);
    },
  );
  test('missing exit DONE and restart never advance or resend', () async {
    await review();
    machine.omitDone = true;
    await engine.skip(engine.task!.id, 0, allRemaining: false, manual: false);
    await until(engine, () => engine.state.phase == ExecutionPhase.recovery);
    expect(engine.state.batch, 0);
    expect(
      journal
          .pending(engine.task!.id)
          .where((e) => e['kind'] == 'skip_completed'),
      isEmpty,
    );
    final recovered = ExecutionEngine(journal);
    expect(recovered.state.skipRequest, isNotNull);
    await expectLater(
      recovered.resume(physicalProgressRetained: true),
      throwsStateError,
    );
    expect(machine.writes.where((b) => b[2] == 5), hasLength(1));
  });
  test('stale task and unconfirmed pause cannot skip', () async {
    await expectLater(engine.reviewSkip('other', 0), throwsStateError);
    machine.omitAck = true;
    await engine.reviewSkip(engine.task!.id, 0);
    await expectLater(
      engine.skip(engine.task!.id, 0, allRemaining: false, manual: true),
      throwsStateError,
    );
  });
  test(
    'failed collection opening can retry without repeating results',
    () async {
      await review();
      await engine.skip(engine.task!.id, 0, allRemaining: true, manual: false);
      await engine.tick(); // stop ACK -> exit; exit ACK/DONE are queued.
      machine.omitDone = true;
      await until(engine, () => engine.state.phase == ExecutionPhase.recovery);
      expect(
        journal
            .pending(engine.task!.id)
            .where((e) => e['kind'] == 'skip_completed'),
        hasLength(1),
      );
      machine.omitDone = false;
      await engine.retryCollection(engine.task!.id, 0);
      await until(
        engine,
        () => engine.state.phase == ExecutionPhase.collecting,
      );
      expect(
        journal
            .pending(engine.task!.id)
            .where((e) => e['kind'] == 'skip_completed'),
        hasLength(1),
      );
      expect(machine.writes.where((b) => b[2] == 5), hasLength(1));
    },
  );
  test(
    'skip across trays requires new recognition and explicit continue',
    () async {
      engine.task = engine.task!.copyWith(
        batches: [
          for (final batch in engine.task!.batches)
            batch.copyWith(tray: batch.index),
        ],
      );
      await review();
      await engine.skip(engine.task!.id, 0, allRemaining: false, manual: false);
      await until(engine, () => engine.state.phase == ExecutionPhase.ready);
      expect(engine.state.batch, 1);
      expect(machine.writes.where((b) => b[2] == 5), hasLength(1));
      await engine.continueTray();
      await until(engine, () => engine.state.phase == ExecutionPhase.running);
      expect(machine.writes.where((b) => b[2] == 5), hasLength(2));
    },
  );
}

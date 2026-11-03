import 'dart:io';

import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_device_runtime/device_runtime.dart';
import 'package:pillxai_execution_core/execution_core.dart';
import 'package:test/test.dart';

import 'execution_test.dart' show until;
import 'support/task_fixture.dart';

void main() {
  late ExecutionEngine engine;
  late MachineSimulator machine;
  late ExecutionJournal journal;
  setUp(() async {
    final dir = Directory.systemTemp.createTempSync('count-review-');
    addTearDown(() => dir.deleteSync(recursive: true));
    journal = ExecutionJournal('${dir.path}/state.db');
    addTearDown(journal.close);
    engine = ExecutionEngine(
      journal,
      commandTimeout: const Duration(milliseconds: 100),
    );
    machine = MachineSimulator(interval: const Duration(hours: 1));
    await engine.connect(machine);
  });

  Future<void> start({int batches = 2, bool sameTray = true}) async {
    final base = fixture(journal.terminalId, batches: batches);
    final task = base.copyWith(
      batches: [
        for (final b in base.batches) sameTray ? b.copyWith(tray: 0) : b,
      ],
      device: base.device.copyWith(
        configuration: base.device.configuration.copyWith(
          barcodeRemovalCloses: true,
        ),
      ),
      recognitionBindings: [
        api.RecognitionBinding(
          source_: api.RecognitionBindingSource_Enum.barcode,
          value: '000010',
          residentId: base.plan.residentId,
        ),
      ],
    );
    await engine.attach(task);
    await until(engine, () => engine.state.phase == ExecutionPhase.ready);
    await engine.begin(task.copyWith(state: api.TaskState.started));
    await until(engine, () => engine.state.phase == ExecutionPhase.running);
    machine.emit('number:1,width:20');
    machine.emit('machine_state:CNT_ERR');
    machine.emit('machine_state:CNT_ERR');
    machine.emit('machine_state:FINISH');
    await engine.tick();
  }

  Future<void> confirm() => engine.confirmCountReview(engine.task!.id, 0);
  for (final changeTray in [false, true]) {
    test('manual review gates next batch, changeTray=$changeTray', () async {
      await start(sameTray: !changeTray);
      await expectLater(confirm(), throwsStateError);
      await until(
        engine,
        () => engine.state.phase == ExecutionPhase.reviewingCount,
      );
      expect(engine.state.count, 1);
      expect(machine.writes.where((b) => b[2] == 5), hasLength(1));
      expect(machine.writes.where((b) => b[2] == 0), hasLength(1));
      expect(machine.writes.where((b) => b[2] == 3), hasLength(2));
      if (changeTray) await expectLater(confirm(), throwsStateError);
      machine.uid = null;
      machine.emit('DISAPPEARED,000010');
      await expectLater(confirm(), throwsStateError);
      machine.emit('APPEARED,000011');
      await expectLater(confirm(), throwsStateError);
      machine.emit('APPEARED,000010');
      await confirm();
      await until(engine, () => engine.state.phase == ExecutionPhase.running);
      expect(engine.state.batch, 1);
      expect(engine.task!.manualBatches, [0]);
      expect(machine.writes.where((b) => b[2] == 5), hasLength(2));
      await expectLater(confirm(), throwsStateError);
    });
  }
  for (final removedBefore in [false, true]) {
    test(
      'last review shares open tray, removedBefore=$removedBefore',
      () async {
        await start(batches: 1);
        await until(
          engine,
          () => engine.state.phase == ExecutionPhase.reviewingCount,
        );
        if (removedBefore) machine.emit('DISAPPEARED,000010');
        await engine.tick();
        expect(machine.writes.where((b) => b[2] == 4), isEmpty);
        await confirm();
      machine.emit('machine_state:CNT_ERR');
        if (!removedBefore) machine.emit('DISAPPEARED,000010');
        await until(
          engine,
          () => engine.state.phase == ExecutionPhase.completed,
        );
        expect(machine.writes.where((b) => b[2] == 3), hasLength(2));
        expect(machine.writes.where((b) => b[2] == 4), hasLength(1));
        expect(engine.state.count, 1);
        expect(engine.task!.manualBatches, [0]);
      },
    );
  }
  test('missing exit DONE and restart cannot resume faulty batch', () async {
    await start();
    machine.omitDone = true;
    await until(engine, () => engine.state.phase == ExecutionPhase.recovery);
    final restored = ExecutionEngine(journal);
    await expectLater(
      restored.resume(physicalProgressRetained: true),
      throwsStateError,
    );
    expect(machine.writes.where((b) => b[2] == 3), hasLength(1));
    expect(engine.task!.manualBatches, isEmpty);
  });

  test(
    'a reported stall during tray review blocks confirmation until released',
    () async {
      await start();
      await until(
        engine,
        () => engine.state.phase == ExecutionPhase.reviewingCount,
      );
      machine.emit('stalled:3');
      await expectLater(confirm(), throwsStateError);
      expect(engine.state.phase, ExecutionPhase.reviewingCount);
      await engine.confirmStallNotice(
        engine.stallNotices.single['id'] as String,
        release: true,
      );
      await engine.tick();
      expect(engine.state.batch, 0);
      await confirm();
      expect(engine.task!.manualBatches, [0]);
    },
  );
}

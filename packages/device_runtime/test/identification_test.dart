import 'dart:io';

import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_device_runtime/device_runtime.dart';
import 'package:pillxai_execution_core/execution_core.dart';
import 'package:test/test.dart';

import 'support/task_fixture.dart';

void main() {
  late Directory directory;
  late ExecutionJournal journal;
  late ExecutionEngine engine;
  late MachineSimulator machine;
  setUp(() async {
    directory = Directory.systemTemp.createTempSync('scan-resident-');
    journal = ExecutionJournal('${directory.path}/execution.sqlite');
    engine = ExecutionEngine(journal);
    machine = MachineSimulator(uid: null);
    await engine.connect(machine);
  });
  tearDown(() {
    journal.close();
    directory.deleteSync(recursive: true);
  });

  Future<void> scan() async {
    await engine.openForIdentification();
    await engine.tick();
    machine.emit('APPEARED,000010');
    await engine.tick();
  }

  api.TaskView task() {
    final value = fixture(journal.terminalId, batches: 1);
    return value.copyWith(
      recognitionBindings: [
        api.RecognitionBinding(
          source_: api.RecognitionBindingSource_Enum.barcode,
          value: '000010',
          residentId: value.plan.residentId,
        ),
      ],
    );
  }

  test(
    'scan first attaches without reopening and starts only with permit',
    () async {
      await scan();
      expect(engine.state.barcode, '000010');
      expect(engine.identifying, isTrue);
      final claimed = task();
      await engine.attach(claimed);
      expect(engine.recognized, isTrue);
      expect(engine.state.phase, ExecutionPhase.ready);
      expect(machine.writes.where((b) => b[2] == 3), hasLength(1));
      expect(machine.writes.where((b) => b[2] == 5), isEmpty);
      await engine.begin(claimed.copyWith(state: api.TaskState.started));
      for (var i = 0; i < 4; i++) {
        await engine.tick();
      }
      expect(machine.writes.where((b) => b[2] == 5), hasLength(1));
    },
  );

  test('removal queued during claim prevents start, does not reopen', () async {
    await scan();
    machine.emit('DISAPPEARED,000010');
    final claimed = task();
    await engine.attach(claimed);
    expect(engine.recognized, isFalse);
    await expectLater(
      engine.begin(claimed.copyWith(state: api.TaskState.started)),
      throwsStateError,
    );
    expect(machine.writes.where((b) => b[2] == 3), hasLength(1));
    expect(machine.writes.where((b) => b[2] == 5), isEmpty);
  });

  test(
    'removal queued while awaiting start permit prevents the matrix',
    () async {
      await scan();
      final claimed = task();
      await engine.attach(claimed);
      machine.emit('DISAPPEARED,000010');
      await expectLater(
        engine.begin(claimed.copyWith(state: api.TaskState.started)),
        throwsStateError,
      );
      expect(engine.recognized, isFalse);
      expect(machine.writes.where((b) => b[2] == 5), isEmpty);
    },
  );

  test('unknown or present box cannot close; matching disappearance permits closing', () async {
    await scan();
    await expectLater(engine.closeIdentification(), throwsStateError);
    machine.emit('DISAPPEARED,other');
    await expectLater(engine.closeIdentification(), throwsStateError);
    machine.emit('DISAPPEARED,000010');
    await engine.closeIdentification();
    await engine.tick();
    expect(engine.state.phase, ExecutionPhase.idle);
    expect(engine.identifying, isFalse);
    expect(journal.setting('identification'), isNull);
  });

  test(
    'interrupted scan is restored as recovery without sending commands',
    () async {
      await scan();
      final recovered = ExecutionEngine(journal);
      expect(recovered.identifying, isTrue);
      expect(recovered.state.phase, ExecutionPhase.recovery);
      await expectLater(recovered.openForIdentification(), throwsStateError);
      expect(machine.writes, hasLength(1));
    },
  );
}

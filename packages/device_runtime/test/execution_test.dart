import 'dart:io';
import 'dart:typed_data';

import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_device_runtime/device_runtime.dart';
import 'package:pillxai_execution_core/execution_core.dart';
import 'package:test/test.dart';

import 'support/task_fixture.dart';

class GateFailureSimulator extends MachineSimulator {
  GateFailureSimulator() : super(interval: const Duration(seconds: 10));
  bool failGate = false;
  @override
  Future<void> write(Uint8List bytes) {
    if (failGate && bytes[2] == 8 && bytes[3] == 1) {
      throw StateError('test gate write failed');
    }
    return super.write(bytes);
  }
}

class OpeningStallSimulator extends MachineSimulator {
  OpeningStallSimulator({super.uid})
    : super(interval: const Duration(seconds: 10));

  @override
  Future<void> write(Uint8List bytes) async {
    if (bytes[2] == 3) emit('stalled:3');
    await super.write(bytes);
    if (bytes[2] == 3) emit('stalled:3');
  }
}

Future<void> until(ExecutionEngine engine, bool Function() condition) async {
  for (var i = 0; i < 300 && !condition(); i++) {
    await engine.tick();
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue, reason: engine.state.toJson().toString());
}

void main() {
  late Directory dir;
  late ExecutionJournal journal;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('pillxai-execution-');
    journal = ExecutionJournal('${dir.path}/execution.sqlite');
  });
  tearDown(() {
    journal.close();
    dir.deleteSync(recursive: true);
  });

  for (final outcome in [
    'complete',
    'missing_ack',
    'reappeared',
    'cancelled',
  ]) {
    test('barcode removal closes immediately, outcome=$outcome', () async {
      final machine = MachineSimulator(
        uid: null,
        interval: const Duration(milliseconds: 1),
      );
      final engine = ExecutionEngine(
        journal,
        removalWindow: const Duration(hours: 1),
      );
      await engine.connect(machine);
      final base = fixture(journal.terminalId, batches: 1);
      final task = base.copyWith(
        device: base.device.copyWith(
          configuration: base.device.configuration.copyWith(
            barcodeRemovalCloses: true,
            feedbackVerified: false,
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
      await engine.tick();
      machine.emit('DISAPPEARED,000010');
      await engine.tick();
      expect(machine.writes.where((b) => b[2] == 4), isEmpty);
      machine.emit('APPEARED,000010');
      await engine.tick();
      await engine.begin(task.copyWith(state: api.TaskState.started));
      await until(
        engine,
        () => engine.state.phase == ExecutionPhase.collecting,
      );
      machine.emit('DISAPPEARED,000011');
      machine.emit('NO CARD');
      await engine.tick();
      expect(machine.writes.where((b) => b[2] == 4), isEmpty);
      machine.omitAck = true;
      machine.omitDone = true;
      if (outcome == 'cancelled') engine.state.cancelRequested = true;
      machine.emit('DISAPPEARED,000010');
      await engine.tick();
      if (outcome == 'cancelled') {
        expect(machine.writes.where((b) => b[2] == 4), isEmpty);
        return;
      }
      expect(engine.state.phase, ExecutionPhase.closing);
      expect(machine.writes.where((b) => b[2] == 4).length, 1);
      machine.emit('DISAPPEARED,000010');
      machine.emit('DONE');
      await engine.tick();
      expect(engine.state.phase, ExecutionPhase.closing);
      if (outcome == 'missing_ack') return;
      machine.emit('ACK');
      await engine.tick();
      expect(engine.state.phase, ExecutionPhase.closing);
      if (outcome == 'reappeared') machine.emit('APPEARED,000010');
      machine.emit('DONE');
      await engine.tick();
      expect(
        engine.state.phase,
        outcome == 'reappeared'
            ? ExecutionPhase.recovery
            : ExecutionPhase.completed,
      );
      expect(machine.writes.where((b) => b[2] == 4).length, 1);
    });
  }

  test('barcode appears/disappears, persists until event, and keeps RFID independent', () async {
    final machine = MachineSimulator(uid: null);
    final engine = ExecutionEngine(journal);
    await engine.connect(machine);
    final base = fixture(journal.terminalId);
    final task = base.copyWith(
      recognitionBindings: [
        api.RecognitionBinding(
          source_: api.RecognitionBindingSource_Enum.barcode,
          value: '000010',
          residentId: base.plan.residentId,
        ),
        api.RecognitionBinding(
          source_: api.RecognitionBindingSource_Enum.rfid,
          value: 'FFFF',
          residentId: 'other',
        ),
      ],
    );
    await engine.attach(task);
    await engine.tick();
    machine.emit('APPEARED,000010');
    await engine.tick();
    expect(engine.recognized, isTrue);
    expect(engine.state.phase, ExecutionPhase.ready);
    expect(engine.recognitionSource, 'barcode');
    engine.state.barcodeAt = DateTime.now().subtract(
      const Duration(minutes: 5),
    );
    machine.emit('UID:ABCD'); // unbound RFID does not defeat a valid barcode
    machine.emit('NO CARD');
    machine.emit(
      'DISAPPEARED,999999',
    ); // delayed disappearance of a different barcode
    await engine.tick();
    expect(engine.recognized, isTrue);
    machine.emit('UID:FFFF');
    await engine.tick();
    expect(engine.recognitionConflict, isTrue);
    expect(engine.recognized, isFalse);
    machine.emit('NO CARD');
    await engine.tick();
    expect(engine.recognized, isTrue);
    machine.emit('DISAPPEARED,000010');
    await engine.tick();
    expect(engine.state.barcode, isNull);
    expect(engine.state.phase, ExecutionPhase.recognizing);
    expect(engine.recognized, isFalse);
    await expectLater(
      engine.begin(task.copyWith(state: api.TaskState.started)),
      throwsStateError,
    );
    expect(machine.writes.length, 1); // only the explicitly requested open
    machine.emit('UID:A1B2C3D4');
    machine.emit('APPEARED,000010');
    machine.emit('DISAPPEARED,000010');
    await engine.tick();
    expect(engine.recognized, isTrue);
    expect(engine.recognitionSource, 'rfid');
    await engine.disconnect();
    expect(engine.recognized, isFalse);
    expect(engine.state.uid, isNull);
    expect(engine.state.barcode, isNull);
    await engine.connect(machine);
    expect(engine.recognized, isFalse);
  });

  test(
    'barcode lost while parameters are pending prevents matrix write',
    () async {
      final machine = MachineSimulator(uid: null);
      final engine = ExecutionEngine(journal);
      await engine.connect(machine);
      final base = fixture(journal.terminalId);
      final task = base.copyWith(
        recognitionBindings: [
          api.RecognitionBinding(
            source_: api.RecognitionBindingSource_Enum.barcode,
            value: '000010',
            residentId: base.plan.residentId,
          ),
        ],
      );
      await engine.attach(task);
      await engine.tick();
      machine.emit('APPEARED,000010');
      await engine.tick();
      await engine.begin(task.copyWith(state: api.TaskState.started));
      machine.emit('DISAPPEARED,000010');
      await engine.tick();
      await engine.tick();
      expect(machine.writes.where((b) => b[2] == 5), isEmpty);
      expect(engine.state.phase, ExecutionPhase.recovery);
    },
  );

  test('opening stalls are recorded without blocking fresh recognition or sending commands', () async {
    final machine = OpeningStallSimulator(uid: null);
    final engine = ExecutionEngine(journal);
    await engine.connect(machine);
    final task = fixture(journal.terminalId);
    await engine.attach(task);
    await engine.tick();
    expect(engine.state.phase, ExecutionPhase.recognizing);
    expect(engine.state.pending, isNull);
    expect(machine.writes.length, 1);
    await expectLater(
      engine.begin(task.copyWith(state: api.TaskState.started)),
      throwsStateError,
    );
    machine.insertTray('A1B2C3D4');
    machine.emit('stall2');
    await engine.tick();
    expect(engine.state.phase, ExecutionPhase.ready);
    expect(engine.recognized, isTrue);
    expect(machine.writes.length, 1);
    final stalls = journal
        .pending(task.id)
        .where(
          (event) =>
              event['kind'] == 'feedback' &&
              event['detail']['kind'] == 'stalled',
        );
    expect(stalls.length, 3);
    expect(
      stalls.every(
        (event) => event['detail']['ignored_reason'] == 'opening_phase',
      ),
      isTrue,
    );
    expect(
      journal.pending(task.id).where((event) => event['kind'] == 'recovery'),
      isEmpty,
    );
  });

  for (final phase in [
    ExecutionPhase.starting,
    ExecutionPhase.running,
    ExecutionPhase.paused,
  ]) {
    test('stall during $phase still blocks execution', () async {
      final machine = OpeningStallSimulator(uid: 'A1B2C3D4');
      final engine = ExecutionEngine(journal);
      await engine.connect(machine);
      final task = fixture(journal.terminalId);
      await engine.attach(task);
      await until(engine, () => engine.state.phase == ExecutionPhase.ready);
      await engine.begin(task.copyWith(state: api.TaskState.started));
      if (phase != ExecutionPhase.starting) {
        await until(engine, () => engine.state.phase == ExecutionPhase.running);
      }
      if (phase == ExecutionPhase.paused) {
        await engine.pause();
        await until(engine, () => engine.state.phase == ExecutionPhase.paused);
      }
      final writes = machine.writes.length;
      machine.emit('stalled:3');
      await engine.tick();
      expect(engine.state.phase, ExecutionPhase.recovery);
      expect(machine.writes.length, writes);
    });
  }

  test(
    'tray change and collection opening ignore stalls but closing does not',
    () async {
      final machine = OpeningStallSimulator(uid: 'A1B2C3D4');
      final engine = ExecutionEngine(journal, removalWindow: Duration.zero);
      await engine.connect(machine);
      final task = fixture(journal.terminalId);
      await engine.attach(task);
      await until(engine, () => engine.state.phase == ExecutionPhase.ready);
      await engine.begin(task.copyWith(state: api.TaskState.started));
      for (var batch = 0; batch < 2; batch++) {
        await until(engine, () => engine.state.phase == ExecutionPhase.running);
        machine.emit('number:2,width:20');
        machine.emit('machine_state:FINISH');
        await until(
          engine,
          () => batch == 0
              ? engine.state.phase == ExecutionPhase.ready
              : engine.state.phase == ExecutionPhase.collecting,
        );
        if (batch == 0) await engine.continueTray();
      }
      machine.emit('stalled:3');
      await engine.tick();
      expect(engine.state.phase, ExecutionPhase.collecting);
      expect(machine.writes.where((bytes) => bytes[2] == 5).length, 2);
      machine.omitDone = true;
      machine.removeTray();
      await engine.tick();
      expect(engine.state.phase, ExecutionPhase.closing);
      machine.emit('stalled:3');
      await engine.tick();
      expect(engine.state.phase, ExecutionPhase.recovery);
      expect(
        journal
            .pending(task.id)
            .where((event) => event['kind'] == 'collection_ready'),
        isEmpty,
      );
    },
  );

  test(
    'ignored opening stall cannot replace missing command acknowledgement',
    () async {
      final machine = OpeningStallSimulator()..omitAck = true;
      final engine = ExecutionEngine(
        journal,
        commandTimeout: const Duration(milliseconds: 20),
      );
      await engine.connect(machine);
      await engine.attach(fixture(journal.terminalId));
      await until(engine, () => engine.state.phase == ExecutionPhase.recovery);
      expect(engine.state.message, contains('设备应答超时'));
      expect(machine.writes.length, 1);
    },
  );

  test('prestart gate becomes A0; successful manual values and next drug stay separate', () async {
    final machine = MachineSimulator(interval: const Duration(seconds: 10));
    final engine = ExecutionEngine(journal);
    await engine.connect(machine);
    final source = fixture(journal.terminalId);
    final task = source.copyWith(
      batches: [source.batches[0], source.batches[1].copyWith(tray: 0)],
    );
    await engine.attach(task);
    await until(engine, () => engine.state.phase == ExecutionPhase.ready);
    await engine.setGate(0.6);
    await until(engine, () => engine.state.pending == null);
    await engine.begin(task.copyWith(state: api.TaskState.started));
    await until(engine, () => engine.state.phase == ExecutionPhase.running);
    var evidence = journal.pending(task.id);
    expect(
      evidence.firstWhere(
        (e) => e['kind'] == 'batch_started',
      )['detail']['gate'],
      0.6,
    );
    await engine.setGate(0.4);
    await until(engine, () => engine.state.pending == null);
    machine.emit('number:1,width:20');
    machine.emit('number:2,width:20');
    machine.emit('machine_state:FINISH');
    await until(
      engine,
      () =>
          engine.state.batch == 1 &&
          engine.state.phase == ExecutionPhase.running,
    );
    evidence = journal.pending(task.id);
    final starts = evidence.where((e) => e['kind'] == 'batch_started').toList();
    expect(starts.length, 2);
    expect(starts[1]['detail']['gate'], task.batches[1].parameters.gate);
    final adjustments = evidence
        .where((e) => e['kind'] == 'manual_gate_written')
        .toList();
    expect(adjustments.map((e) => e['detail']['gate']), [0.6, 0.4]);
    expect(adjustments.every((e) => e['batch'] == 0), isTrue);
    expect(machine.writes.where((b) => b[2] == 5).length, 2);
    // Pulse samples alone never cause host-side real-time speed changes.
    expect(machine.writes.where((b) => b[2] == 8 && b[3] == 0).length, 2);
  });

  test('failed gate write is not a successful adjustment and retains previous value', () async {
    final machine = GateFailureSimulator();
    final engine = ExecutionEngine(journal);
    await engine.connect(machine);
    final task = fixture(journal.terminalId, batches: 1);
    await engine.attach(task);
    await until(engine, () => engine.state.phase == ExecutionPhase.ready);
    await engine.begin(task.copyWith(state: api.TaskState.started));
    await until(engine, () => engine.state.phase == ExecutionPhase.running);
    final initial = engine.state.gate;
    machine.failGate = true;
    await expectLater(engine.setGate(0.2), throwsStateError);
    expect(engine.state.phase, ExecutionPhase.recovery);
    expect(engine.state.gate, initial);
    expect(
      journal.pending(task.id).where((e) => e['kind'] == 'manual_gate_written'),
      isEmpty,
    );
  });

  test('真实编码模拟双盘：领取落盘、识别、暂停恢复、换盘、取盒、补传', () async {
    final machine = MachineSimulator(
      interval: const Duration(milliseconds: 80),
    );
    final engine = ExecutionEngine(
      journal,
      removalWindow: const Duration(milliseconds: 20),
    );
    await engine.connect(machine);
    expect(machine.writes, isEmpty);
    final task = fixture(journal.terminalId);
    await engine.attach(task);
    expect(journal.active()!['task']['id'], task.id);
    await until(engine, () => engine.state.phase == ExecutionPhase.ready);
    await engine.begin(task.copyWith(state: api.TaskState.started));
    await until(engine, () => engine.state.phase == ExecutionPhase.running);
    await engine.pause();
    await until(engine, () => engine.state.phase == ExecutionPhase.paused);
    final count = engine.state.count;
    await engine.resume();
    await until(engine, () => engine.state.phase == ExecutionPhase.running);
    expect(engine.state.count, greaterThanOrEqualTo(count));
    expect(machine.writes.where((b) => b[2] == 5).length, 1);
    await until(
      engine,
      () =>
          engine.state.batch == 1 && engine.state.phase == ExecutionPhase.ready,
    );
    await engine.continueTray();
    await until(engine, () => engine.state.phase == ExecutionPhase.collecting);
    machine.emit('NO CARD');
    await engine.tick();
    expect(engine.state.phase, ExecutionPhase.collecting);
    machine.removeTray();
    await until(engine, () => engine.state.phase == ExecutionPhase.completed);
    expect(machine.writes.where((b) => b[2] == 5).length, 2);
    expect(machine.writes.where((b) => b[2] == 4).length, 1);
    final pending = journal.pending(task.id);
    expect(pending.where((e) => e['kind'] == 'batch_finished').length, 2);
    expect(pending.last['kind'], 'collection_ready');
    engine.acknowledge(engine.state.sequence);
    expect(journal.active(), isNull);
  });

  test('错人识别阻止开始，命令超时保持未知且不重发', () async {
    final machine = MachineSimulator(uid: 'FFFF')..omitAck = true;
    final engine = ExecutionEngine(
      journal,
      commandTimeout: const Duration(milliseconds: 20),
    );
    await engine.connect(machine);
    final task = fixture(journal.terminalId);
    await engine.attach(task);
    await until(engine, () => engine.state.phase == ExecutionPhase.recovery);
    expect(machine.writes.length, 1);
    await expectLater(
      engine.begin(task.copyWith(state: api.TaskState.started)),
      throwsStateError,
    );
    expect(machine.writes.length, 1);
  });

  test('重启保留事件与进度，不自动恢复；复位禁止直接继续', () async {
    final machine = MachineSimulator(interval: const Duration(seconds: 1));
    var engine = ExecutionEngine(journal);
    await engine.connect(machine);
    final task = fixture(journal.terminalId, batches: 1);
    await engine.attach(task);
    await until(engine, () => engine.state.phase == ExecutionPhase.ready);
    await engine.begin(task.copyWith(state: api.TaskState.started));
    await until(engine, () => engine.state.phase == ExecutionPhase.running);
    final written = machine.writes.length;
    journal.close();
    journal = ExecutionJournal('${dir.path}/execution.sqlite');
    engine = ExecutionEngine(journal);
    expect(engine.state.phase, ExecutionPhase.recovery);
    expect(machine.writes.length, written);
    expect(journal.pending(task.id), isNotEmpty);
    await engine.connect(machine);
    await expectLater(engine.resume(), throwsStateError);
    machine.emit('machine init');
    await engine.tick();
    await expectLater(
      engine.resume(physicalProgressRetained: true),
      throwsStateError,
    );
    await engine.requestDiscard();
    expect(machine.writes.length, written);
    expect(journal.active()!['state']['phase'], 'deleting');
    engine.finishDiscard();
    expect(journal.active(), isNull);
    expect(journal.pending(task.id), isEmpty);
  });

  test('启动参数途中受控退出先落盘，停止后不继续发送参数或矩阵', () async {
    final machine = MachineSimulator();
    final engine = ExecutionEngine(journal);
    await engine.connect(machine);
    final task = fixture(journal.terminalId);
    await engine.attach(task);
    await until(engine, () => engine.state.phase == ExecutionPhase.ready);
    await engine.begin(task.copyWith(state: api.TaskState.started));
    await engine.stopForCancel();
    expect(journal.active()!['state']['cancel_requested'], isTrue);
    await until(
      engine,
      () => engine.state.phase == ExecutionPhase.awaitingSafeConfirmation,
    );
    expect(machine.writes.where((b) => b[2] == 5), isEmpty);
    await engine.confirmCancelled();
    expect(journal.pending(task.id).last['kind'], 'cancelled');
    await expectLater(engine.connect(machine), throwsStateError);
    expect(engine.state.phase, ExecutionPhase.cancelled);
    await engine.disconnect();
    expect(engine.state.phase, ExecutionPhase.cancelled);
    machine.emit('machine_state:FINISH');
    await engine.tick();
    expect(journal.pending(task.id).last['kind'], 'cancelled');
    engine.acknowledge(engine.state.sequence);
    expect(journal.active(), isNull);
  });

  test('完成后继续到达的反馈不污染已结束任务的补传队列', () async {
    final machine = MachineSimulator(
      interval: const Duration(milliseconds: 10),
    );
    final engine = ExecutionEngine(journal, removalWindow: Duration.zero);
    await engine.connect(machine);
    final task = fixture(journal.terminalId, batches: 1);
    await engine.attach(task);
    await until(engine, () => engine.state.phase == ExecutionPhase.ready);
    await engine.begin(task.copyWith(state: api.TaskState.started));
    await until(engine, () => engine.state.phase == ExecutionPhase.collecting);
    machine.removeTray();
    await until(engine, () => engine.state.phase == ExecutionPhase.completed);
    final count = journal.pendingCount(task.id);
    machine.emit('number:2,width:10');
    await engine.tick();
    expect(journal.pendingCount(task.id), count);
  });
}

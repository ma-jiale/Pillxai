import 'dart:io';

import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_device_runtime/device_runtime.dart';
import 'package:pillxai_execution_core/execution_core.dart';
import 'package:test/test.dart';

import 'support/task_fixture.dart';

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

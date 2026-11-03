import 'dart:io';
import 'dart:typed_data';

import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_device_runtime/device_runtime.dart';
import 'package:pillxai_execution_core/execution_core.dart';
import 'package:test/test.dart';

import 'execution_test.dart' show until;
import 'support/task_fixture.dart';

class DisconnectingMachine extends MachineSimulator {
  DisconnectingMachine() : super(interval: const Duration(hours: 1));
  Object? readFailure;
  Object? writeFailure;
  bool silent = false;
  @override
  Future<Uint8List> read() async {
    if (readFailure != null) throw readFailure!;
    return silent ? Uint8List(0) : super.read();
  }

  @override
  Future<void> write(Uint8List bytes) async {
    if (writeFailure != null) throw writeFailure!;
    await super.write(bytes);
  }
}

void main() {
  late Directory dir;
  late ExecutionJournal journal;
  late ExecutionEngine engine;
  late DisconnectingMachine machine;
  setUp(() async {
    dir = Directory.systemTemp.createTempSync('pillxai-disconnect-');
    journal = ExecutionJournal('${dir.path}/state.db');
    engine = ExecutionEngine(
      journal,
      commandTimeout: const Duration(milliseconds: 50),
    );
    machine = DisconnectingMachine();
    await engine.connect(machine);
    final task = fixture(journal.terminalId);
    await engine.attach(task);
    await until(engine, () => engine.state.phase == ExecutionPhase.ready);
    await engine.begin(task.copyWith(state: api.TaskState.started));
    await until(engine, () => engine.state.phase == ExecutionPhase.running);
  });
  tearDown(() {
    journal.close();
    dir.deleteSync(recursive: true);
  });

  test('explicit disconnect durably terminates without sending commands; notice survives cleanup', () async {
    final id = engine.task!.id;
    final writes = machine.writes.length;
    machine.readFailure = const DeviceDisconnected();
    await engine.tick();
    expect(engine.state.phase, ExecutionPhase.deleting);
    expect(engine.state.disconnectedDiscard, isTrue);
    expect(engine.state.connected, isFalse);
    expect(machine.writes.length, writes);
    engine.acknowledge(999, taskState: api.TaskState.cancelled);
    expect(engine.state.phase, ExecutionPhase.deleting);
    journal.close();
    journal = ExecutionJournal('${dir.path}/state.db');
    engine = ExecutionEngine(journal);
    expect(engine.state.phase, ExecutionPhase.deleting);
    expect(engine.state.disconnectedDiscard, isTrue);
    await expectLater(engine.connect(machine), throwsStateError);
    engine.finishDiscard();
    expect(journal.active(), isNull);
    expect(journal.pending(id), isEmpty);
    expect((engine.view()['disconnect_notice'] as Map)['task_id'], id);
    final session = TerminalSession(
      journal: journal,
      hardwareTransport: (_) => machine,
      ports: () => [],
      publish: (_) {},
      platform: 'test',
    );
    await session.command('dismiss_disconnect_notice', {'task_id': 'stale'});
    expect(session.view()['disconnect_notice'], isNotNull);
    await session.command('dismiss_disconnect_notice', {'task_id': id});
    expect(session.view()['disconnect_notice'], isNull);
  });

  test(
    'write disconnect also terminates rather than turning into recovery',
    () async {
      machine.writeFailure = const DeviceDisconnected();
      await expectLater(engine.pause(), throwsA(isA<DeviceDisconnected>()));
      expect(engine.state.phase, ExecutionPhase.deleting);
      await engine.tick();
      expect(engine.state.phase, ExecutionPhase.deleting);
    },
  );

  test(
    'silence without pending commands does not declare disconnection',
    () async {
      machine.silent = true;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await engine.tick();
      expect(engine.state.phase, ExecutionPhase.running);
      expect(engine.state.disconnectedDiscard, isFalse);
      expect(journal.setting('disconnect_notice'), isNull);
      expect(engine.task, isNotNull);
    },
  );

  test('unclassified transport error preserves recovery evidence', () async {
    machine.readFailure = StateError('buffer overflow');
    await engine.tick();
    expect(engine.state.phase, ExecutionPhase.recovery);
    expect(journal.setting('disconnect_notice'), isNull);
    expect(engine.task, isNotNull);
  });
}

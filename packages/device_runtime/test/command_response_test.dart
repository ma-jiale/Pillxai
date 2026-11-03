import 'dart:io';
import 'dart:typed_data';

import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_device_runtime/device_runtime.dart';
import 'package:pillxai_execution_core/execution_core.dart';
import 'package:test/test.dart';

import 'execution_test.dart' show until;
import 'support/task_fixture.dart';

class FailingConnection extends MachineSimulator {
  FailingConnection({required this.duringOpen});
  final bool duringOpen;
  @override
  Future<void> open() async {
    if (duringOpen) throw const DeviceDisconnected();
    await super.open();
  }

  @override
  Future<Uint8List> read() async => throw const DeviceDisconnected();
}

void main() {
  late Directory directory;
  late ExecutionJournal journal;
  late ExecutionEngine engine;
  late MachineSimulator machine;
  late DateTime clock;
  setUp(() async {
    directory = Directory.systemTemp.createTempSync('pillxai-command-');
    journal = ExecutionJournal('${directory.path}/state.db');
    clock = DateTime.utc(2026, 11, 2);
    engine = ExecutionEngine(journal, now: () => clock);
    machine = MachineSimulator(interval: const Duration(hours: 1));
    await engine.connect(machine);
  });
  tearDown(() {
    journal.close();
    directory.deleteSync(recursive: true);
  });
  Future<void> advance(int milliseconds) async {
    clock = clock.add(Duration(milliseconds: milliseconds));
    await engine.tick();
  }

  Future<void> running({int batches = 2}) async {
    final task = fixture(journal.terminalId, batches: batches);
    await engine.attach(task);
    await until(engine, () => engine.state.phase == ExecutionPhase.ready);
    await engine.begin(task.copyWith(state: api.TaskState.started));
    await until(engine, () => engine.state.phase == ExecutionPhase.running);
  }

  for (final acknowledgeStop in [true, false]) {
    test('final FINISH gates collection on stop ACK: $acknowledgeStop', () async {
      await running(batches: 1);
      final before = machine.writes.length;
      machine.omitAck = true;
      machine.emit('number:2,width:20');
      machine.emit('machine_state:FINISH');
      await advance(0);
      expect(machine.writes.skip(before).single, [0xaa, 0xbb, 8, 0, 0, 0, 0, 0, 8, 0]);
      machine.emit('DONE');
      await advance(0);
      expect(machine.writes.length, before + 1);
      if (acknowledgeStop) {
        machine.emit('ACK');
        await advance(0);
        expect(machine.writes.last[2], 3);
      } else {
        for (var attempt = 0; attempt < 6; attempt++) {
          await advance(200);
        }
        expect(engine.state.phase, ExecutionPhase.recovery);
        expect(machine.writes.skip(before).any((bytes) => bytes[2] == 3), isFalse);
      }
    });
  }

  test('ordinary command: 200ms per attempt, exactly six sends, then one durable loss notice', () async {
    machine.omitAck = true;
    await engine.attach(fixture(journal.terminalId));
    for (var attempt = 1; attempt <= 6; attempt++) {
      expect(machine.writes.length, attempt);
      await advance(199);
      expect(machine.writes.length, attempt);
      expect(engine.state.connected, isTrue);
      await advance(1);
    }
    expect(machine.writes.length, 6);
    expect(
      machine.writes.every(
        (bytes) => bytes.toString() == machine.writes.first.toString(),
      ),
      isTrue,
    );
    expect(engine.state.phase, ExecutionPhase.deleting);
    expect(engine.state.connected, isFalse);
    final notice = journal.setting('disconnect_notice');
    final sequence = engine.state.sequence;
    machine.emit('ACK');
    machine.emit('DONE');
    machine.emit('machine_state:FINISH');
    await advance(10000);
    expect(journal.setting('disconnect_notice'), notice);
    expect(engine.state.sequence, sequence);
    expect(machine.writes.length, 6);
  });

  for (final attempts in [1, 3, 6]) {
    test(
      'ACK on attempt $attempts ends retry, does not resend or advance without DONE',
      () async {
        machine.omitAck = true;
        machine.omitDone = true;
        await engine.attach(fixture(journal.terminalId));
        for (var i = 1; i < attempts; i++) {
          await advance(200);
        }
        machine.emit('ACK');
        await advance(199);
        expect(engine.state.acknowledged, isTrue);
        await advance(500);
        expect(machine.writes.length, attempts);
        expect(engine.state.phase, ExecutionPhase.opening);
        machine.emit('DONE');
        await engine.tick();
        expect(engine.state.phase, ExecutionPhase.recognizing);
        expect(journal.setting('disconnect_notice'), isNull);
      },
    );
  }

  test(
    'DONE timeout is measured from first ACK; duplicate ACK does not extend it',
    () async {
      machine.omitAck = true;
      machine.omitDone = true;
      await engine.attach(fixture(journal.terminalId));
      await advance(180);
      machine.emit('ACK');
      await engine.tick();
      await advance(9999);
      expect(engine.state.phase, ExecutionPhase.opening);
      machine.emit('ACK');
      await advance(1);
      expect(engine.state.phase, ExecutionPhase.recovery);
      expect(engine.state.message, contains('等待 DONE 超时'));
      expect(engine.state.connected, isTrue);
      expect(machine.writes, hasLength(1));
      expect(journal.setting('disconnect_notice'), isNull);
      machine.emit('UID:ABC123');
      await engine.tick();
      expect(engine.observedUid, 'ABC123');
    },
  );

  test('release stall sends once; missing ACK preserves connection, receiver and unresolved motors', () async {
    await running();
    machine.emit('stalled:2');
    machine.emit('stall3');
    await engine.tick();
    machine.omitAck = true;
    final before = machine.writes.length;
    await engine.releaseStall(2);
    expect(machine.writes.last, [0xaa, 0xbb, 8, 2, 0, 0, 0, 0, 10, 0]);
    for (var i = 0; i < 7; i++) {
      await advance(200);
    }
    expect(machine.writes.length, before + 1);
    expect(engine.state.stalledMotors, [2, 3]);
    expect(engine.state.phase, ExecutionPhase.recovery);
    expect(engine.state.connected, isTrue);
    expect(journal.setting('disconnect_notice'), isNull);
    machine.emit('UID:ABC123');
    await engine.tick();
    expect(engine.observedUid, 'ABC123');
    await expectLater(
      engine.resume(physicalProgressRetained: true),
      throwsStateError,
    );
    machine.omitAck = false;
    await engine.releaseStall(2);
    await engine.tick();
    expect(engine.state.stalledMotors, [3]);
    await engine.releaseStall(3);
    await engine.tick();
    expect(engine.state.stalledMotors, isEmpty);
    expect(engine.state.phase, ExecutionPhase.recovery);
    expect(machine.writes.where((b) => b[2] == 5), hasLength(1));
  });

  test('new stall invalidates pending release before a late ACK', () async {
    await running();
    machine.emit('stall2');
    await engine.tick();
    machine.omitAck = true;
    await engine.releaseStall(2);
    machine.emit('stall2');
    machine.emit('ACK');
    await engine.tick();
    expect(engine.state.stalledMotors, [2]);
    expect(engine.state.pending, isNull);
  });

  test('unchecked confirmation sends nothing; repeated notices group, persist and can be released later', () async {
    await running();
    machine.emit('stall2');
    machine.emit('stalled:2');
    machine.emit('stalled:3');
    await engine.tick();
    expect(engine.stallNotices, hasLength(2));
    final notice = engine.stallNotices.firstWhere(
      (notice) => notice['motor'] == 2,
    );
    final writes = machine.writes.length;
    await engine.confirmStallNotice(notice['id'] as String, release: false);
    expect(machine.writes.length, writes);
    expect(engine.state.stalledMotors, [2, 3]);
    expect(
      engine.stallNotices.firstWhere((n) => n['motor'] == 2)['seen'],
      isTrue,
    );
    final restored = ExecutionEngine(journal);
    expect(restored.stallNotices, hasLength(2));
    expect(restored.state.stalledMotors, [2, 3]);
    engine = restored;
    await engine.connect(machine);
    await engine.confirmStallNotice(notice['id'] as String, release: true);
    expect(machine.writes.length, writes + 1);
    await engine.tick();
    expect(engine.state.stalledMotors, [3]);
    expect(engine.stallNotices.single['motor'], 3);
  });

  test(
    'idle stall is reported and release ACK clears only the selected motor',
    () async {
      machine.emit('stall2');
      machine.emit('stall3');
      await engine.tick();
      expect(engine.stallNotices, hasLength(2));
      final notice = engine.stallNotices.first;
      await engine.confirmStallNotice(notice['id'] as String, release: true);
      await engine.tick();
      expect(engine.state.stalledMotors, [3]);
      expect(engine.state.connected, isTrue);
      expect(engine.task, isNull);
    },
  );

  test(
    'manual disconnect cancels pending retries without the loss dialog',
    () async {
      machine.omitAck = true;
      await engine.attach(fixture(journal.terminalId));
      await engine.disconnect();
      await advance(2000);
      expect(engine.state.phase, ExecutionPhase.recovery);
      expect(machine.writes, hasLength(1));
      expect(journal.setting('disconnect_notice'), isNull);
    },
  );

  for (final duringOpen in [true, false]) {
    test(
      'failed initial connection/drain (open=$duringOpen) does not discard an existing task',
      () async {
        await running();
        await engine.disconnect();
        final next = FailingConnection(duringOpen: duringOpen);
        await expectLater(
          engine.connect(next),
          throwsA(isA<DeviceDisconnected>()),
        );
        expect(engine.state.phase, ExecutionPhase.recovery);
        expect(engine.state.connected, isFalse);
        expect(engine.task, isNotNull);
        expect(next.connected, isFalse);
        expect(journal.setting('disconnect_notice'), isNull);
      },
    );
  }

  test('scan failure never invokes device loss processing', () async {
    final session = TerminalSession(
      journal: journal,
      hardwareTransport: (_) => machine,
      ports: () => throw const DeviceDisconnected(),
      publish: (_) {},
      platform: 'test',
    );
    await expectLater(
      session.command('ports'),
      throwsA(isA<DeviceDisconnected>()),
    );
    expect(journal.setting('disconnect_notice'), isNull);
    expect(engine.state.connected, isTrue);
  });

  test(
    'unacknowledged binding open also reports loss without a task',
    () async {
      machine.omitAck = true;
      await engine.openForBinding();
      for (var i = 0; i < 6; i++) {
        await advance(200);
      }
      expect(engine.state.phase, ExecutionPhase.idle);
      expect(engine.state.connected, isFalse);
      expect(journal.setting('disconnect_notice'), isNotNull);
      expect(machine.writes, hasLength(6));
    },
  );
}

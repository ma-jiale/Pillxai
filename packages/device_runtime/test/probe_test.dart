import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pillxai_device_protocol/device_protocol.dart';
import 'package:pillxai_device_runtime/device_runtime.dart';
import 'package:pillxai_execution_core/execution_core.dart';
import 'package:test/test.dart';

final class FailingWriteTransport implements DeviceTransport {
  int attempts = 0;
  bool closed = false;
  @override
  Future<void> open() async {}
  @override
  Future<Uint8List> read() async => Uint8List(0);
  @override
  Future<void> write(Uint8List bytes) async {
    attempts++;
    throw StateError('write outcome unknown');
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  late Directory directory;
  late String path;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('pillxai-probe-');
    path = '${directory.path}/diagnostics.sqlite';
  });
  tearDown(() => directory.deleteSync(recursive: true));

  test('opening/listening writes no commands, preserves raw split frames after reopen', () async {
    final journal = DiagnosticJournal(path);
    final transport = SimulatedTransport(
      ['A', 'CK\r\nnumber:9,width:20\n', 'NO CARD\n'].map(utf8.encode).toList(),
    );
    final id = await ProbeSession(transport, journal).run(
      mode: 'simulator',
      device: 'fixture',
      duration: const Duration(milliseconds: 120),
    );
    expect(transport.writes, isEmpty);
    journal.close();
    final reopened = DiagnosticJournal(path);
    try {
      final events = reopened.readEvents(id);
      expect(events.where((e) => e['kind'] == 'rx').length, 3);
      expect(events.where((e) => e['kind'] == 'feedback').length, 3);
      expect(reopened.sessions().single['outcome'], 'observation_ended');
    } finally {
      reopened.close();
    }
  });

  test(
    'uncertain physical write is journaled once and never retried',
    () async {
      final journal = DiagnosticJournal(path);
      final transport = FailingWriteTransport();
      try {
        await expectLater(
          ProbeSession(transport, journal).run(
            mode: 'simulator',
            device: 'failure',
            duration: Duration.zero,
            command: Stm32Commands.stop(),
          ),
          throwsStateError,
        );
        expect(transport.attempts, 1);
        expect(transport.closed, isTrue);
        final session = journal.sessions().single;
        final events = journal.readEvents(session['session_id'] as String);
        expect(events.where((e) => e['kind'] == 'write_intent').length, 1);
        expect(events.where((e) => e['kind'] == 'written'), isEmpty);
        expect(session['outcome'], 'failed');
      } finally {
        journal.close();
      }
    },
  );

  test('unfinished session stays open evidence; journal reopen does not invent completion', () {
    final journal = DiagnosticJournal(path);
    final id = journal.beginSession(mode: 'simulator', device: 'interrupted');
    journal.record(id, 'write_intent', {'bytes': Stm32Commands.openTray()});
    journal.close();
    final reopened = DiagnosticJournal(path);
    try {
      expect(reopened.sessions().single['outcome'], 'open');
      expect(reopened.readEvents(id).single['kind'], 'write_intent');
    } finally {
      reopened.close();
    }
  });
}

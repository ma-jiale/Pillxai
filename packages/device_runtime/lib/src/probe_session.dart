import 'dart:typed_data';

import 'package:pillxai_device_protocol/device_protocol.dart';
import 'package:pillxai_execution_core/execution_core.dart';

import 'diagnostic_journal.dart';

/// Records one explicit engineering operation, never retries physical writes.
/// It does not infer ACK/DONE ownership or declare a production task completed.
final class ProbeSession {
  ProbeSession(this.transport, this.journal);
  final DeviceTransport transport;
  final DiagnosticJournal journal;

  Future<String> run({
    required String mode,
    required String device,
    required Duration duration,
    Uint8List? command,
    bool Function()? shouldStop,
    void Function(DeviceEvent)? onEvent,
  }) async {
    final session = journal.beginSession(mode: mode, device: device);
    final decoder = FeedbackDecoder();
    var outcome = 'failed';
    try {
      await transport.open();
      journal.record(session, 'connected', {'device': device});
      if (command != null) {
        journal.record(session, 'write_intent', {'bytes': command});
        await transport.write(command);
        journal.record(session, 'written', {'bytes': command});
      }
      final elapsed = Stopwatch()..start();
      while (elapsed.elapsed < duration && !(shouldStop?.call() ?? false)) {
        final bytes = await transport.read();
        if (bytes.isNotEmpty) {
          final events = decoder.add(bytes);
          journal.recordIncoming(session, bytes, events);
          for (final event in events) {
            onEvent?.call(event);
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      outcome = shouldStop?.call() == true
          ? 'interrupted'
          : 'observation_ended';
      return session;
    } catch (error) {
      journal.record(session, 'error', {
        'message': error.toString(),
        'device_state': 'unknown',
      });
      rethrow;
    } finally {
      final partial = decoder.finish();
      try {
        await transport.close();
      } catch (error) {
        outcome = 'close_failed';
        journal.record(session, 'error', {'message': error.toString()});
      } finally {
        if (partial != null) {
          journal.record(session, 'feedback', partial.toJson());
        }
        journal.endSession(session, outcome);
      }
    }
  }
}

import 'dart:convert';

import 'package:pillxai_execution_core/execution_core.dart';

/// LF/CRLF framing with a bounded partial line. Raw chunks are journaled upstream.
/// An overlong line is discarded through its LF, never interpreted from a suffix.
final class FeedbackDecoder {
  FeedbackDecoder({this.maxLineBytes = 4096}) {
    if (maxLineBytes < 1) {
      throw ArgumentError.value(maxLineBytes, 'maxLineBytes');
    }
  }

  final int maxLineBytes;
  final List<int> _pending = [];
  bool _discarding = false;

  List<DeviceEvent> add(List<int> bytes) {
    final events = <DeviceEvent>[];
    for (final byte in bytes) {
      if (byte == 10) {
        if (_discarding) {
          _discarding = false;
          continue;
        }
        if (_pending.isNotEmpty && _pending.last == 13) _pending.removeLast();
        try {
          final line = utf8.decode(_pending);
          if (line.isNotEmpty) events.add(parseFeedback(line));
        } on FormatException {
          events.add(DeviceEvent(DeviceEventKind.malformed, 'invalid UTF-8'));
        }
        _pending.clear();
      } else if (!_discarding) {
        if (_pending.length == maxLineBytes) {
          events.add(
            DeviceEvent(
              DeviceEventKind.malformed,
              'line exceeds $maxLineBytes bytes',
            ),
          );
          _pending.clear();
          _discarding = true;
        } else {
          _pending.add(byte);
        }
      }
    }
    return events;
  }

  /// Called on disconnect. A truncated line is evidence, not a complete event.
  DeviceEvent? finish() {
    final hadPartial = _pending.isNotEmpty || _discarding;
    final raw = utf8.decode(_pending, allowMalformed: true);
    _pending.clear();
    _discarding = false;
    return hadPartial
        ? DeviceEvent(DeviceEventKind.malformed, 'truncated: $raw')
        : null;
  }
}

DeviceEvent parseFeedback(String raw) {
  final line = raw.trim();
  const exact = {
    'ACK': DeviceEventKind.acknowledged,
    'DONE': DeviceEventKind.actionDone,
    'machine_state:FINISH': DeviceEventKind.batchFinished,
    'machine_state:CNT_ERR': DeviceEventKind.counterError,
    'machine init': DeviceEventKind.initialized,
    'NO CARD': DeviceEventKind.noCard,
  };
  if (exact[line] case final kind?) return DeviceEvent(kind, raw);
  final count = RegExp(r'^number:(\d+)(?:,\s*|\s+)width:([+-]?\d+(?:\.\d+)?)$')
      .firstMatch(line);
  if (count != null) {
    final value = int.tryParse(count[1]!);
    if (value != null) {
      return DeviceEvent(
        DeviceEventKind.count,
        raw,
        count: value,
        width: count[2],
      );
    }
  }
  for (final entry in {
    'pills out:': DeviceEventKind.outputCount,
    'cleaned pills:': DeviceEventKind.recoveredCount,
    'stalled:': DeviceEventKind.stalled,
    'stall': DeviceEventKind.stalled,
  }.entries) {
    if (line.startsWith(entry.key)) {
      final suffix = line.substring(entry.key.length);
      if (RegExp(r'^\d+$').hasMatch(suffix)) {
        final value = int.tryParse(suffix);
        if (value != null) return DeviceEvent(entry.value, raw, count: value);
      }
    }
  }
  final uid = RegExp(r'^UID:([0-9a-fA-F]{1,64})$').firstMatch(line);
  if (uid != null) {
    return DeviceEvent(DeviceEventKind.rfid, raw, uid: uid[1]!.toUpperCase());
  }
  return DeviceEvent(DeviceEventKind.unknown, raw);
}

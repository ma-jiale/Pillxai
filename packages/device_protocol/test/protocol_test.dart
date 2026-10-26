import 'dart:convert';

import 'package:pillxai_device_protocol/device_protocol.dart';
import 'package:pillxai_execution_core/execution_core.dart';
import 'package:test/test.dart';

void main() {
  test('confirmed gate and close-tray byte fixtures', () {
    expect(Stm32Commands.setGate(0.7), [
      0xaa,
      0xbb,
      8,
      1,
      0x33,
      0x33,
      0x33,
      0x3f,
      0xe1,
      0,
    ]);
    expect(Stm32Commands.closeTray(), [0xaa, 0xbb, 4, 4, 0]);
    expect(Stm32Commands.stop(), [0xaa, 0xbb, 8, 0, 0, 0, 0, 0, 8, 0]);
    expect(Stm32Commands.resume(), [0xaa, 0xbb, 8, 0, 0, 0, 0, 0x41, 0x49, 0]);
  });
  test('matrix preserves row order and rejects truncation', () {
    final rows = List.generate(
      4,
      (row) => List.generate(7, (column) => row * 7 + column),
    );
    final bytes = Stm32Commands.matrix(rows);
    expect(bytes.sublist(3, 31), List.generate(28, (i) => i));
    expect(bytes.sublist(31), [0x7f, 1]); // 5 + sum(0..27) = 383
    expect(
      () => Stm32Commands.matrix([
        [256],
      ]),
      throwsArgumentError,
    );
    rows[0][0] = -1;
    expect(() => Stm32Commands.matrix(rows), throwsArgumentError);
    expect(() => Stm32Commands.setGate(double.nan), throwsArgumentError);
  });
  test('all chunk boundaries preserve ACK, count and FINISH separately', () {
    final bytes = utf8.encode(
      'ACK\r\nnumber:9,width:20\nmachine_state:FINISH\n',
    );
    for (var split = 0; split <= bytes.length; split++) {
      final decoder = FeedbackDecoder();
      final events = [
        ...decoder.add(bytes.sublist(0, split)),
        ...decoder.add(bytes.sublist(split)),
      ];
      expect(events.map((e) => e.kind), [
        DeviceEventKind.acknowledged,
        DeviceEventKind.count,
        DeviceEventKind.batchFinished,
      ]);
      expect(events[1].count, 9);
      expect(decoder.finish(), isNull);
    }
  });
  test('unknown, partial and oversized lines never become completion', () {
    final decoder = FeedbackDecoder(maxLineBytes: 24);
    expect(
      decoder.add(utf8.encode('${'x' * 25}ACK\nDONE\n')).map((e) => e.kind),
      [DeviceEventKind.malformed, DeviceEventKind.actionDone],
    );
    expect(parseFeedback('number:-1,width:20').kind, DeviceEventKind.unknown);
    expect(parseFeedback('NO CARD').kind, DeviceEventKind.noCard);
    expect(parseFeedback('UID:aabb').uid, 'AABB');
    decoder.add(utf8.encode('machine_state:FINISH'));
    expect(decoder.finish()!.kind, DeviceEventKind.malformed);
    expect(
      decoder.add(utf8.encode('ACK\n')).single.kind,
      DeviceEventKind.acknowledged,
    );
  });
}

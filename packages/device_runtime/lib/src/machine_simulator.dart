import 'dart:convert';
import 'dart:typed_data';

import 'package:pillxai_execution_core/execution_core.dart';

/// Explicit engineering simulator. Consumes the real encoded byte protocol.
class MachineSimulator implements DeviceTransport {
  MachineSimulator({
    this.uid = 'A1B2C3D4',
    this.interval = const Duration(milliseconds: 120),
  });
  String? uid;
  final Duration interval;
  bool connected = false;
  bool running = false;
  int target = 0;
  int count = 0;
  bool omitAck = false;
  bool omitDone = false;
  final writes = <Uint8List>[];
  final _bytes = <int>[];
  DateTime last = DateTime.now();
  DateTime lastUid = DateTime.now();
  void emit(String line) => _bytes.addAll(utf8.encode('$line\r\n'));
  void removeTray() {
    uid = null;
    emit('SIM:TRAY_ABSENT');
  }

  void insertTray(String value) {
    uid = value;
    emit('SIM:TRAY_PRESENT');
    emit('UID:$value');
  }

  @override
  Future<void> open() async {
    connected = true;
  }

  @override
  Future<void> close() async {
    connected = false;
  }

  @override
  Future<Uint8List> read() async {
    if (!connected) throw StateError('模拟连接已断开');
    final now = DateTime.now();
    if (uid != null && now.difference(lastUid) >= const Duration(seconds: 1)) {
      emit('UID:$uid');
      lastUid = now;
    }
    if (running && now.difference(last) >= interval) {
      last = now;
      count++;
      emit('number:$count,width:20');
      if (count == target) {
        running = false;
        emit('machine_state:FINISH');
      }
    }
    final result = Uint8List.fromList(_bytes);
    _bytes.clear();
    return result;
  }

  @override
  Future<void> write(Uint8List bytes) async {
    if (!connected) throw StateError('模拟连接已断开');
    writes.add(Uint8List.fromList(bytes));
    if (!omitAck) emit('ACK');
    switch (bytes[2]) {
      case 3:
        if (!omitDone) emit('DONE');
        emit('SIM:TRAY_PRESENT');
        if (uid != null) emit('UID:$uid');
      case 4:
        if (!omitDone) emit('DONE');
        emit('SIM:READY');
      case 5:
        count = 0;
        target = bytes.sublist(3, 31).fold(0, (sum, n) => sum + n);
        running = target > 0;
        last = DateTime.now();
      case 8:
        if (bytes[3] == 0) {
          final value = ByteData.sublistView(
            bytes,
            4,
            8,
          ).getFloat32(0, Endian.little);
          if (value == 0) running = false;
          if (value == 8 && count < target) running = true;
        }
      case 0:
        running = false;
        if (!omitDone) emit('DONE');
    }
  }
}

import 'dart:typed_data';

/// Only confirmed commands from docs/04; no default production parameters.
abstract final class Stm32Commands {
  static Uint8List stop() => _motor(0, 0);
  static Uint8List resume() => _motor(0, 8);
  static Uint8List exitMedicine() => _frame(0x00, []);
  static Uint8List openTray() => _frame(0x03, []);
  static Uint8List closeTray() => _frame(0x04, []);

  static Uint8List setGate(double value) {
    if (!value.isFinite || value < 0 || value > 1) {
      throw ArgumentError.value(value, 'value', 'Gate must be in [0, 1]');
    }
    return _motor(1, value);
  }

  static Uint8List setTurntable(double value) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(
        value,
        'value',
        'A finite nonnegative value is required',
      );
    }
    return _motor(0, value);
  }

  /// Row-major physical protocol coordinates; no business/date mapping here.
  static Uint8List matrix(List<List<int>> rows) {
    if (rows.length != 4 || rows.any((row) => row.length != 7)) {
      throw ArgumentError('Matrix must have exactly 4 rows and 7 columns');
    }
    final cells = rows.expand((row) => row).toList();
    if (cells.any((value) => value < 0 || value > 255)) {
      throw ArgumentError('Every cell must be an integer in [0, 255]');
    }
    return _frame(0x05, cells);
  }

  static Uint8List _motor(int target, double value) {
    final data = ByteData(4)..setFloat32(0, value, Endian.little);
    if (!data.getFloat32(0, Endian.little).isFinite) {
      throw ArgumentError('Value cannot be represented as a finite float32');
    }
    return _frame(0x08, [target, ...data.buffer.asUint8List()]);
  }

  static Uint8List _frame(int command, List<int> payload) {
    final checksum = payload.fold(command, (sum, byte) => sum + byte) & 0xffff;
    return Uint8List.fromList([
      0xaa,
      0xbb,
      command,
      ...payload,
      checksum & 0xff,
      checksum >> 8,
    ]);
  }
}

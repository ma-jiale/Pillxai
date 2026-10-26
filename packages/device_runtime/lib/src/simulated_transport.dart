import 'dart:typed_data';

import 'package:pillxai_execution_core/execution_core.dart';

/// A scripted byte stream, not simulated production completion or coverage.
final class SimulatedTransport implements DeviceTransport {
  SimulatedTransport(List<List<int>> chunks)
    : _chunks = chunks.map(Uint8List.fromList).toList();

  final List<Uint8List> _chunks;
  final List<Uint8List> writes = [];
  bool _open = false;

  @override
  Future<void> open() async {
    if (_open) throw StateError('Already connected');
    _open = true;
  }

  @override
  Future<Uint8List> read() async {
    if (!_open) throw StateError('Disconnected');
    return _chunks.isEmpty ? Uint8List(0) : _chunks.removeAt(0);
  }

  @override
  Future<void> write(Uint8List bytes) async {
    if (!_open) throw StateError('Disconnected');
    writes.add(Uint8List.fromList(bytes));
  }

  @override
  Future<void> close() async => _open = false;
}

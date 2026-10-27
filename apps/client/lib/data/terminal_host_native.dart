import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:pillxai_device_runtime/device_runtime.dart';

import 'terminal_host.dart';
import 'terminal_host_stub.dart';

TerminalHost createHost() =>
    Platform.isWindows ? NativeTerminalHost() : UnavailableTerminalHost();

class NativeTerminalHost implements TerminalHost {
  NativeTerminalHost({this.dataDirectory});
  final String? dataDirectory;
  final _updates = StreamController<Map<String, dynamic>>.broadcast();
  final _pending = <int, Completer<dynamic>>{};
  final _ready = Completer<void>();
  ReceivePort? _receive;
  ReceivePort? _failurePort;
  RandomAccessFile? _lock;
  bool _closing = false;
  Object? _failure;
  Isolate? _isolate;
  SendPort? _send;
  int _id = 0;
  @override
  bool get supported => true;
  @override
  Stream<Map<String, dynamic>> get updates => _updates.stream;
  @override
  Future<void> initialize() async {
    if (_failure != null) throw _failure!;
    if (_receive != null) return _ready.future;
    _receive = ReceivePort();
    _receive!.listen((value) {
      final message = value as Map;
      if (message['port'] != null) {
        _send = message['port'] as SendPort;
        _ready.complete();
      }
      if (message['view'] != null) {
        _updates.add(Map<String, dynamic>.from(message['view'] as Map));
      }
      if (message['worker_error'] != null) {
        _updates.add({'worker_error': message['worker_error']});
      }
      if (message['id'] != null) {
        final completer = _pending.remove(message['id']);
        if (message['error'] != null) {
          completer?.completeError(StateError(message['error'] as String));
        } else {
          completer?.complete(message['result']);
        }
      }
    });
    const compiledPath = String.fromEnvironment('PILLXAI_DATA_DIR');
    final directory =
        dataDirectory ??
        (compiledPath.isNotEmpty
            ? compiledPath
            : '${Directory.current.path}/.var/terminal');
    Directory(directory).createSync(recursive: true);
    _lock = File('$directory/owner.lock').openSync(mode: FileMode.append);
    try {
      _lock!.lockSync(FileLock.exclusive);
    } catch (_) {
      _lock!.closeSync();
      _lock = null;
      _failure = StateError('本机执行核心已由另一窗口占用，请使用原窗口。');
      throw _failure!;
    }
    _failurePort = ReceivePort();
    _failurePort!.listen((event) {
      if (_closing) return;
      _failure = StateError('本机执行核心已中断，必须重开并核对现场；不会自动恢复。');
      _updates.add({'worker_error': _failure.toString()});
      if (!_ready.isCompleted) _ready.completeError(_failure!);
      for (final item in _pending.values) {
        item.completeError(_failure!);
      }
      _pending.clear();
    });
    _isolate = await Isolate.spawn(
      terminalWorker,
      {'output': _receive!.sendPort, 'database': '$directory/execution.sqlite'},
      onError: _failurePort!.sendPort,
      onExit: _failurePort!.sendPort,
    );
    await _ready.future.timeout(const Duration(seconds: 15));
  }

  @override
  Future<dynamic> command(
    String command, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (_failure != null) throw _failure!;
    await initialize();
    final id = ++_id;
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    _send!.send({'id': id, 'command': command, 'data': data});
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        _pending.remove(id);
        throw TimeoutException('本机操作结果未确认，请核对状态，勿重复启动。');
      },
    );
  }

  @override
  Future<void> close() async {
    _closing = true;
    if (_send != null) await command('shutdown');
    _isolate?.kill();
    _receive?.close();
    _failurePort?.close();
    _lock?.closeSync();
    await _updates.close();
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_execution_core/execution_core.dart';

import 'execution_engine.dart';
import 'execution_journal.dart';
import 'machine_simulator.dart';

/// Serialized commands and ticks shared by Windows and Android hosts.
/// Platforms supply transport only; they never advance the task themselves.
class TerminalSession {
  TerminalSession({
    required this.journal,
    required this.hardwareTransport,
    required this.ports,
    required this.publish,
    required this.platform,
  }) : engine = ExecutionEngine(journal);

  final ExecutionJournal journal;
  final ExecutionEngine engine;
  final DeviceTransport Function(Map<String, dynamic>) hardwareTransport;
  final FutureOr<List<Object?>> Function() ports;
  final void Function(Map<String, dynamic>) publish;
  final String platform;
  Future<void> _queue = Future.value();
  Timer? _timer;
  bool _polling = false;
  bool _closed = false;
  String _previous = '';

  Map<String, dynamic> view() => {...engine.view(), 'platform': platform};

  void _publish() {
    final encoded = jsonEncode(view());
    if (encoded == _previous) return;
    _previous = encoded;
    publish(jsonDecode(encoded) as Map<String, dynamic>);
  }

  void start() {
    if (_closed) throw StateError('执行宿主已关闭。');
    _timer ??= Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (_polling || _closed) return;
      _polling = true;
      _enqueue(() async {
        try {
          await engine.tick();
        } finally {
          _polling = false;
        }
      }).catchError((Object error) {
        publish({'worker_error': error.toString()});
      });
    });
    _publish();
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _queue.then((_) async {
      if (_closed) throw StateError('执行宿主已关闭。');
      try {
        return await action();
      } finally {
        if (!_closed) _publish();
      }
    });
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Object?> command(
    String operation, [
    Map<String, dynamic> data = const {},
  ]) => _enqueue(() async {
    switch (operation) {
      case 'view':
        return jsonDecode(jsonEncode(view()));
      case 'ports':
        return await ports();
      case 'configure':
        if (engine.active || journal.setting('claim_intent') != null) {
          throw StateError('任务未结束，不能更换连接配置。');
        }
        if (engine.state.connected) await engine.disconnect();
        journal.setSetting('connection', data);
      case 'connect':
        final config = Map<String, dynamic>.from(
          journal.setting('connection') as Map? ?? {},
        );
        if (config.isEmpty) throw StateError('请先保存设备连接。');
        await engine.connect(
          config['mode'] == 'simulator'
              ? MachineSimulator(uid: config['uid'] as String? ?? 'A1B2C3D4')
              : hardwareTransport(config),
        );
      case 'disconnect':
        await engine.disconnect();
      case 'open_binding':
        await engine.openForBinding();
      case 'claim_intent':
        journal.setSetting('claim_intent', data.isEmpty ? null : data);
      case 'attach':
        await engine.attach(api.TaskView.fromJson(data)!);
      case 'begin':
        await engine.begin(api.TaskView.fromJson(data)!);
      case 'continue_tray':
        await engine.continueTray();
      case 'pause':
        await engine.pause();
      case 'resume':
        await engine.resume(
          physicalProgressRetained: data['confirmed'] == true,
        );
      case 'gate':
        await engine.setGate((data['value'] as num).toDouble());
      case 'stop':
        await engine.stopForCancel();
      case 'cancel':
        await engine.confirmCancelled();
      case 'discard':
        await engine.requestDiscard();
      case 'discarded':
        engine.finishDiscard();
      case 'pending':
        return engine.task == null ? [] : journal.pending(engine.task!.id);
      case 'acknowledge':
        engine.acknowledge(data['sequence'] as int);
      case 'sim_remove':
      case 'sim_insert':
        if (engine.transport is! MachineSimulator) {
          throw StateError('仅模拟机可注入操作。');
        }
        final simulator = engine.transport as MachineSimulator;
        if (operation == 'sim_remove') {
          simulator.removeTray();
        } else {
          simulator.insertTray(data['uid'] as String);
        }
      case 'shutdown':
        if (engine.active || journal.setting('claim_intent') != null) {
          throw StateError('任务尚未结束。');
        }
        await engine.disconnect();
        _timer?.cancel();
        journal.close();
        _closed = true;
      default:
        throw ArgumentError('Unknown terminal operation: $operation');
    }
    return null;
  });
}

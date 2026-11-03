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

  Map<String, dynamic> view() => {
    ...engine.view(),
    'platform': platform,
    'update_lock': journal.setting('update_lock'),
  };

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
    // Durable and serialized with claims/device commands, not a UI-only check.
    if (journal.setting('update_lock') != null &&
        ![
          'view',
          'ports',
          'pending',
          'acknowledge',
          'update_unlock',
        ].contains(operation)) {
      throw StateError('正在安装更新，请先完成或取消安装。');
    }
    switch (operation) {
      case 'update_lock':
        await engine.tick();
        if (engine.active ||
            journal.active() != null ||
            journal.setting('claim_intent') != null ||
            journal.totalPendingCount != 0 ||
            engine.storageFailed ||
            engine.state.trayPresent ||
            engine.state.uid != null ||
            engine.state.barcode != null ||
            engine.state.pending != null ||
            engine.state.phase != ExecutionPhase.idle) {
          throw StateError('请先完成任务、取盒收仓和结果同步，再安装更新。');
        }
        final token = data['token'];
        if (token is! String || token.isEmpty) throw ArgumentError('缺少安装标识。');
        journal.setSetting('update_lock', token);
        await engine.disconnect();
      case 'update_unlock':
        if (journal.setting('update_lock') != data['token']) {
          throw StateError('安装标识不匹配，保留更新锁。');
        }
        journal.setSetting('update_lock', null);
      case 'view':
        return jsonDecode(jsonEncode(view()));
      case 'dismiss_disconnect_notice':
        final notice = journal.setting('disconnect_notice') as Map?;
        if (notice?['task_id'] == data['task_id']) {
          journal.setSetting('disconnect_notice', null);
        }
      case 'ports':
        return await ports();
      case 'configure':
        if (engine.active ||
            engine.identifying ||
            journal.setting('claim_intent') != null) {
          throw StateError('任务未结束，不能更换连接配置。');
        }
        if (engine.state.connected) await engine.disconnect();
        final previous = journal.setting('connection') as Map?;
        final devicePorts = Map<String, dynamic>.from(
          previous?['device_ports'] as Map? ?? {},
        );
        if (previous?['device_id'] case final String id) {
          devicePorts[id] = previous?['port'];
        }
        if (data['device_id'] case final String id) {
          devicePorts[id] = data['port'];
        }
        final config = {...data, 'device_ports': devicePorts};
        if (platform == 'windows' && data['device_id'] is String) {
          final transports = Map<String, dynamic>.from(
            previous?['device_transports'] as Map? ?? {},
          );
          final deviceId = data['device_id'] as String;
          if (data['transport'] != null) {
            transports[deviceId] = data['transport'];
          } else if (previous?['device_id'] != deviceId ||
              previous?['port'] != data['port'] ||
              data['mode'] != 'hardware') {
            transports.remove(deviceId);
          }
          config['device_transports'] = transports;
        }
        journal.setSetting('connection', config);
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
      case 'open_identification':
        await engine.openForIdentification();
      case 'close_identification':
        await engine.closeIdentification();
      case 'claim_intent':
        if (data['scan_barcode'] != null) {
          await engine.tick();
          if (!engine.identifying ||
              !engine.state.connected ||
              engine.state.phase != ExecutionPhase.recognizing ||
              engine.state.barcode != data['scan_barcode']) {
            throw StateError('药盒已变化，请重新扫描并核对。');
          }
        }
        journal.setSetting('claim_intent', data.isEmpty ? null : data);
      case 'attach':
        await engine.attach(api.TaskView.fromJson(data)!);
      case 'begin':
        await engine.begin(api.TaskView.fromJson(data)!);
      case 'continue_tray':
        await engine.continueTray();
      case 'cancel_preparation':
        await engine.cancelPreparation();
      case 'pause':
        await engine.pause();
      case 'retry_collection':
        await engine.retryCollection(
          data['task_id'] as String,
          data['batch'] as int,
        );
      case 'review_skip':
        await engine.reviewSkip(
          data['task_id'] as String,
          data['batch'] as int,
        );
      case 'confirm_count_review':
        await engine.confirmCountReview(
          data['task_id'] as String,
          data['batch'] as int,
        );
      case 'cancel_skip':
        await engine.cancelSkip(
          data['task_id'] as String,
          data['batch'] as int,
        );
      case 'skip':
        await engine.skip(
          data['task_id'] as String,
          data['batch'] as int,
          allRemaining: data['all_remaining'] == true,
          manual: data['manual'] == true,
        );
      case 'begin_next':
        await engine.beginNextBatch(
          data['task_id'] as String,
          data['batch'] as int,
        );
      case 'resume':
        await engine.resume(
          physicalProgressRetained: data['confirmed'] == true,
        );
      case 'gate':
        await engine.setGate((data['value'] as num).toDouble());
      case 'release_stall':
        await engine.releaseStall(data['motor'] as int);
      case 'confirm_stall_notice':
        await engine.confirmStallNotice(
          data['id'] as String,
          release: data['release'] == true,
        );
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
        engine.acknowledge(
          data['sequence'] as int,
          taskState: api.TaskState.fromJson(data['task_state']),
          learningResults: data['learning_results'] == null
              ? null
              // In-process Android calls can contain nested SDK model objects.
              // Normalize them as on the serialized platform command boundary.
              : api.LearningResult.listFromJson(
                  jsonDecode(jsonEncode(data['learning_results'])),
                ),
        );
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
        if (engine.active ||
            engine.identifying ||
            journal.setting('claim_intent') != null) {
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

import 'dart:typed_data';

import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_device_protocol/device_protocol.dart';
import 'package:pillxai_execution_core/execution_core.dart';

import 'execution_journal.dart';

/// Sole owner of commands, feedback association and durable terminal state.
/// The host serializes tick/actions; neither widgets nor HTTP responses drive counts.
class ExecutionEngine {
  ExecutionEngine(
    this.journal, {
    this.commandTimeout = const Duration(seconds: 10),
    this.removalWindow = const Duration(seconds: 2),
  }) {
    final saved = journal.active();
    if (saved != null) {
      task = api.TaskView.fromJson(saved['task'])!;
      state = ExecutionState.fromJson(saved['state'] as Map<String, dynamic>);
      state.connected = false;
      state.uid = null;
      state.uidAt = null;
      state.pending = null;
      if (state.active && state.phase != ExecutionPhase.deleting) {
        state.phase = ExecutionPhase.recovery;
        state.message = '检测到未结束任务。请核对原机器、药盒和进度；不会自动重发矩阵。';
        _save('recovered');
      }
    }
  }
  final ExecutionJournal journal;
  final Duration commandTimeout;
  final Duration removalWindow;
  api.TaskView? task;
  ExecutionState state = ExecutionState();
  DeviceTransport? transport;
  FeedbackDecoder decoder = FeedbackDecoder();
  final rawLines = <String>[];
  String? observedUid;
  DateTime? observedAt;
  String? _nextCommand;
  DateTime? _deadline;
  bool _polling = false;
  bool storageFailed = false;

  api.BatchPlan get batch => task!.batches[state.batch];
  bool get active => task != null;
  bool get recognized =>
      state.uid != null &&
      state.uidAt != null &&
      DateTime.now().toUtc().difference(state.uidAt!) <
          const Duration(seconds: 30) &&
      task!.labels.contains(state.uid);

  Map<String, dynamic> view() => {
    'terminal_id': journal.terminalId,
    'task': task?.toJson(),
    'state': state.toJson(),
    'observed_uid': observedUid,
    'observed_at': observedAt?.toIso8601String(),
    'raw_lines': rawLines,
    'pending_count': task == null ? 0 : journal.pendingCount(task!.id),
    'recognized': task != null && recognized,
    'storage_failed': storageFailed,
    'configuration': journal.setting('connection'),
    'claim_intent': journal.setting('claim_intent'),
  };

  void _save(String kind, [Map<String, dynamic>? detail]) {
    try {
      if (task == null) {
        journal.observe(kind, detail ?? {});
      } else {
        journal.save(task!, state, kind: kind, detail: detail);
      }
    } catch (_) {
      storageFailed = true;
      state.phase = ExecutionPhase.recovery;
      state.pending = null;
      _nextCommand = null;
      state.message = '本机保存失败，已阻止新增命令。请立即停止投料并核对机器。';
      rethrow;
    }
  }

  Future<void> connect(DeviceTransport next) async {
    if (state.connected) throw StateError('请先断开当前连接。');
    if (state.phase == ExecutionPhase.deleting) {
      throw StateError('任务正在删除，不能连接设备。');
    }
    transport = next;
    decoder = FeedbackDecoder();
    await next.open();
    state.connected = true;
    observedUid = null;
    observedAt = null;
    state.uid = null;
    state.uidAt = null;
    if (!active) {
      state.phase = ExecutionPhase.idle;
      state.pending = null;
    }
    _save('connected');
    // Opening a connection sends nothing. Old buffered replies cannot authorize a command.
    final buffered = await next.read();
    for (final event in decoder.add(buffered)) {
      _raw(event.raw);
      if (event.kind == DeviceEventKind.initialized && active) {
        state.resetObserved = true;
        _save('reset_observed');
      }
    }
  }

  Future<void> disconnect() async {
    await transport?.close();
    state.connected = false;
    if (active && state.phase != ExecutionPhase.deleting) {
      _fault('设备连接已断开，请核对现场。');
    }
  }

  Future<void> attach(api.TaskView claimed) async {
    if (active ||
        !state.connected ||
        storageFailed ||
        state.phase != ExecutionPhase.idle) {
      throw StateError('本机未就绪或已有任务。');
    }
    if (claimed.terminalId != journal.terminalId ||
        claimed.state != api.TaskState.claimed) {
      throw StateError('任务归属或阶段不正确。');
    }
    task = claimed;
    state = ExecutionState()
      ..connected = true
      ..phase = ExecutionPhase.opening;
    _save('claimed');
    journal.setSetting('claim_intent', null);
    await _send('open');
  }

  Future<void> openForBinding() async {
    if (active || state.phase != ExecutionPhase.idle) {
      throw StateError('设备有任务或待核对动作。');
    }
    state.phase = ExecutionPhase.opening;
    await _send('open');
  }

  Future<void> begin(api.TaskView permitted) async {
    if (state.phase != ExecutionPhase.ready ||
        !recognized ||
        permitted.id != task?.id ||
        permitted.state != api.TaskState.started) {
      throw StateError('请取得启动许可并重新核对药盒。');
    }
    task = permitted;
    state.permitted = true;
    _save('start_permit');
    await _beginBatch();
  }

  Future<void> continueTray() async {
    if (!state.permitted ||
        state.phase != ExecutionPhase.ready ||
        !recognized) {
      throw StateError('请等待本盘新的药盒识别，并确认已经换好。');
    }
    await _beginBatch();
  }

  Future<void> _beginBatch() async {
    state.phase = ExecutionPhase.starting;
    state.count = 0;
    state.gate = batch.parameters.gate.toDouble();
    state.matrixIssued = false;
    state.message = '正在下发当前药物参数';
    await _send('turntable');
  }

  Future<void> pause() async {
    if (state.phase != ExecutionPhase.running) throw StateError('当前不能暂停。');
    state.phase = ExecutionPhase.pausing;
    await _send('pause');
  }

  Future<void> resume({bool physicalProgressRetained = false}) async {
    if (state.cancelRequested ||
        state.resetObserved ||
        !state.matrixIssued ||
        !state.permitted) {
      throw StateError('机器复位或批次未建立，请现场核对，不能直接恢复。');
    }
    if (state.phase == ExecutionPhase.recovery && !physicalProgressRetained) {
      throw StateError('请先确认原机器未复位、药盒和药物未更换且批次进度仍保留。');
    }
    if (![
      ExecutionPhase.paused,
      ExecutionPhase.recovery,
    ].contains(state.phase)) {
      throw StateError('当前不能恢复。');
    }
    state.phase = ExecutionPhase.resuming;
    await _send('resume');
  }

  Future<void> setGate(double value) async {
    if (![
      ExecutionPhase.running,
      ExecutionPhase.paused,
    ].contains(state.phase)) {
      throw StateError('当前不能调整开口。');
    }
    await _send('manual_gate', gate: value);
  }

  Future<void> stopForCancel() async {
    if (!active || state.phase == ExecutionPhase.deleting) {
      throw StateError('没有可结束的任务。');
    }
    state.cancelRequested = true;
    _nextCommand = null;
    state.phase = ExecutionPhase.stopping;
    _save('cancel_intent');
    if (state.pending == null) await _send('stop_cancel');
  }

  Future<void> confirmCancelled() async {
    if (state.phase != ExecutionPhase.awaitingSafeConfirmation) {
      throw StateError('须先停止并确认现场安全。');
    }
    state.phase = ExecutionPhase.cancelled;
    state.message = '本次已取消，等待同步。';
    _save('cancelled', {'physical_scene_safe': true});
    await transport?.close();
    state.connected = false;
  }

  Future<void> requestDiscard() async {
    if (!active ||
        [
          ExecutionPhase.completed,
          ExecutionPhase.cancelled,
        ].contains(state.phase)) {
      throw StateError('只能删除当前未结束任务。');
    }
    state.phase = ExecutionPhase.deleting;
    state.pending = null;
    _nextCommand = null;
    state.message = '正在结束并删除，等待中央确认。';
    _save('delete_intent');
    await transport?.close();
    state.connected = false;
    // This path never sends stop/open/close; the operator has confirmed a safe scene.
  }

  void finishDiscard() {
    if (state.phase != ExecutionPhase.deleting) throw StateError('没有删除意图。');
    journal.discard(task!.id);
    task = null;
    state = ExecutionState();
    rawLines.clear();
  }

  void acknowledge(int sequence) {
    if (task == null) return;
    journal.acknowledge(task!.id, sequence);
    if ([
          ExecutionPhase.completed,
          ExecutionPhase.cancelled,
        ].contains(state.phase) &&
        journal.pendingCount(task!.id) == 0) {
      journal.release(task!.id);
      task = null;
      state = ExecutionState()
        ..connected = transport != null && state.connected;
    }
  }

  void _raw(String line) {
    rawLines.add(line);
    if (rawLines.length > 80) rawLines.removeAt(0);
  }

  void _fault(String message) {
    state.phase = ExecutionPhase.recovery;
    state.pending = null;
    _nextCommand = null;
    state.message = '$message 请停止投料并核对现场，不会自动重发。';
    state.uid = null;
    state.uidAt = null;
    _save('recovery', {'message': message});
  }

  Future<void> tick() async {
    if ([
      ExecutionPhase.completed,
      ExecutionPhase.cancelled,
      ExecutionPhase.deleting,
    ].contains(state.phase)) {
      return;
    }
    if (_polling || !state.connected || transport == null || storageFailed) {
      return;
    }
    _polling = true;
    try {
      final bytes = await transport!.read();
      if (bytes.isNotEmpty) {
        _save('rx', {'bytes': bytes.toList()});
        for (final event in decoder.add(bytes)) {
          _raw(event.raw);
          await _feedback(event);
        }
      }
      if (state.pending != null &&
          _deadline != null &&
          DateTime.now().isAfter(_deadline!)) {
        _fault('设备应答超时，动作结果未知。');
      }
      if (state.phase == ExecutionPhase.ready && !recognized) {
        state.phase = ExecutionPhase.recognizing;
        state.message = '识别已过期，等待新的药盒反馈。';
        _save('recognition_expired');
      }
      if (state.phase == ExecutionPhase.collecting &&
          !state.trayPresent &&
          state.absentAt != null &&
          DateTime.now().toUtc().difference(state.absentAt!) >= removalWindow &&
          state.pending == null) {
        state.phase = ExecutionPhase.closing;
        state.closeDone = false;
        state.readyObserved = false;
        await _send('close');
      }
      final next = _nextCommand;
      _nextCommand = null;
      if (next != null && state.phase != ExecutionPhase.recovery) {
        await _send(next);
      }
    } catch (error) {
      if (!storageFailed) {
        state.connected = false;
        _fault('设备通信失败：$error');
        await transport?.close();
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _feedback(DeviceEvent event) async {
    if (event.kind == DeviceEventKind.rfid) {
      observedUid = event.uid;
      observedAt = DateTime.now().toUtc();
    }
    if (event.kind == DeviceEventKind.noCard) {
      observedUid = null;
      observedAt = null;
    }
    if (!active) {
      if (event.kind == DeviceEventKind.acknowledged && state.pending == 'open') {
        state.acknowledged = true;
      }
      if (event.kind == DeviceEventKind.actionDone &&
          state.pending == 'open' &&
          state.acknowledged) {
        state.pending = null;
        state.phase = ExecutionPhase.idle;
        state.message = '已收到开仓完成反馈，可放入标签读取。';
      }
      return;
    }
    _save('feedback', event.toJson());
    if (event.kind == DeviceEventKind.initialized) {
      state.resetObserved = true;
      _fault('机器报告重新初始化，原批次进度不能直接恢复。');
      return;
    }
    if ([
      DeviceEventKind.counterError,
      DeviceEventKind.stalled,
      DeviceEventKind.malformed,
    ].contains(event.kind)) {
      _fault('收到异常反馈：${event.raw}');
      return;
    }
    final config = task!.device.configuration;
    if (config.feedbackVerified) {
      if (event.raw.trim() == config.trayPresentLine) {
        state.trayPresent = true;
        state.absentAt = null;
        if (state.phase == ExecutionPhase.closing) {
          _fault('收仓期间检测到药盒重新在轨。');
          return;
        }
      }
      if (event.raw.trim() == config.trayAbsentLine) {
        state.trayPresent = false;
        if (state.phase == ExecutionPhase.collecting) {
          state.absentAt ??= DateTime.now().toUtc();
        }
        if (state.phase == ExecutionPhase.ready) {
          state.uid = null;
          state.phase = ExecutionPhase.recognizing;
        }
      }
      if (event.raw.trim() == config.readyLine &&
          state.phase == ExecutionPhase.closing) {
        state.readyObserved = true;
      }
    }
    if ([
      ExecutionPhase.recognizing,
      ExecutionPhase.ready,
    ].contains(state.phase)) {
      if (event.kind == DeviceEventKind.rfid) {
        state.uid = event.uid;
        state.uidAt = DateTime.now().toUtc();
        state.phase = task!.labels.contains(event.uid)
            ? ExecutionPhase.ready
            : ExecutionPhase.recognizing;
        state.message = state.phase == ExecutionPhase.ready
            ? '药盒识别通过，请核对并开始。'
            : '当前药盒不属于这位长者。';
        _save('recognition', {
          'uid': event.uid,
          'matched': state.phase == ExecutionPhase.ready,
        });
      } else if (event.kind == DeviceEventKind.noCard) {
        state.uid = null;
        state.uidAt = null;
        state.phase = ExecutionPhase.recognizing;
        _save('recognition_lost');
      }
    }
    if (event.kind == DeviceEventKind.acknowledged &&
        state.pending != null &&
        !state.acknowledged) {
      state.acknowledged = true;
      _save('ack', {'command': state.pending});
      if (!['open', 'close', 'exit'].contains(state.pending)) {
        _commandCompleted();
      }
    } else if (event.kind == DeviceEventKind.actionDone &&
        state.pending != null &&
        state.acknowledged &&
        ['open', 'close', 'exit'].contains(state.pending)) {
      _commandCompleted();
    }
    if (event.kind == DeviceEventKind.count &&
        state.matrixIssued &&
        [
          ExecutionPhase.running,
          ExecutionPhase.paused,
          ExecutionPhase.pausing,
          ExecutionPhase.resuming,
        ].contains(state.phase)) {
      final value = event.count!;
      if (value < state.count || value > batch.total) {
        _fault('计数倒退或超出本批目标。');
        return;
      }
      if (value > state.count) {
        state.count = value;
        _save('count', {'count': value, 'width': event.width});
      }
    }
    if (event.kind == DeviceEventKind.batchFinished &&
        state.matrixIssued &&
        state.phase == ExecutionPhase.running) {
      if (state.pending != null) {
        _fault('完成反馈与参数命令应答重叠，须核对本批结果。');
        return;
      }
      if (state.count != batch.total) {
        _fault('完成反馈与累计计数不一致。');
        return;
      }
      _save('batch_finished', {'feedback': event.raw});
      state.matrixIssued = false;
      if (state.batch == task!.batches.length - 1) {
        state.openPurpose = 'collect';
        state.phase = ExecutionPhase.opening;
        _nextCommand = 'open';
      } else {
        final previousTray = batch.tray;
        state.batch++;
        state.count = 0;
        if (batch.tray != previousTray) {
          state.openPurpose = 'change';
          state.phase = ExecutionPhase.changingTray;
          state.uid = null;
          state.uidAt = null;
          _nextCommand = 'open';
        } else {
          state.phase = ExecutionPhase.starting;
          _nextCommand = 'turntable';
        }
      }
      _save('next_stage');
    }
    if (event.kind == DeviceEventKind.batchFinished &&
        state.matrixIssued &&
        [
          ExecutionPhase.paused,
          ExecutionPhase.pausing,
          ExecutionPhase.resuming,
        ].contains(state.phase)) {
      _fault('暂停或恢复期间收到完成反馈，请核对本批结果。');
    }
    if (state.phase == ExecutionPhase.closing &&
        state.closeDone &&
        state.readyObserved &&
        !state.trayPresent) {
      state.phase = ExecutionPhase.completed;
      state.message = '本次已完成，药盒已离轨、设备已就绪。';
      _save('collection_ready', {
        'absent': config.trayAbsentLine,
        'ready': config.readyLine,
      });
    }
  }

  void _commandCompleted() {
    final command = state.pending!;
    state.pending = null;
    _deadline = null;
    if (state.cancelRequested && command != 'stop_cancel') {
      _nextCommand = 'stop_cancel';
      _save('command_done', {'command': command});
      return;
    }
    switch (command) {
      case 'open':
        state.uid = null;
        state.uidAt = null;
        state.absentAt = null;
        if (state.openPurpose == 'collect') {
          state.phase = ExecutionPhase.collecting;
          state.trayPresent = true;
          state.message = '药物处理结束，请取出药盒。等待有效离轨及就绪反馈。';
        } else {
          state.phase = ExecutionPhase.recognizing;
          state.message = state.openPurpose == 'change'
              ? '请换好下一盘，等待新的药盒识别。'
              : '请放入药盒，等待识别。';
        }
      case 'turntable':
        _nextCommand = 'gate';
      case 'gate':
        _nextCommand = 'matrix';
      case 'matrix':
        state.phase = ExecutionPhase.running;
        state.message = '正在分药，可以投药。';
      case 'pause':
        state.phase = ExecutionPhase.paused;
        state.message = '已收到停转确认。';
      case 'resume':
        state.phase = ExecutionPhase.running;
        state.message = '正在继续原批次。';
      case 'stop_cancel':
        state.phase = ExecutionPhase.awaitingSafeConfirmation;
        state.message = '已收到停转确认，请核对机器、药盒和药物后结束。';
      case 'close':
        state.closeDone = true;
      case 'manual_gate':
        state.message = '开口设置已下发，请核对现场。';
    }
    _save('command_done', {'command': command});
  }

  Future<void> _send(String command, {double? gate}) async {
    if (storageFailed || !state.connected || state.pending != null) {
      throw StateError('设备未连接、命令未确认或保存失败。');
    }
    final Uint8List bytes = switch (command) {
      'open' => Stm32Commands.openTray(),
      'close' => Stm32Commands.closeTray(),
      'turntable' => Stm32Commands.setTurntable(
        batch.parameters.turntable.toDouble(),
      ),
      'gate' => Stm32Commands.setGate(batch.parameters.gate.toDouble()),
      'matrix' => Stm32Commands.matrix(batch.matrix),
      'pause' || 'stop_cancel' => Stm32Commands.stop(),
      'resume' => Stm32Commands.resume(),
      'exit' => Stm32Commands.exitMedicine(),
      'manual_gate' => Stm32Commands.setGate(gate!),
      _ => throw ArgumentError(command),
    };
    state.pending = command;
    if (command == 'manual_gate') state.gate = gate;
    state.acknowledged = false;
    if (command == 'matrix') state.matrixIssued = true;
    _deadline = DateTime.now().add(commandTimeout);
    _save('write_intent', {
      'command': command,
      'bytes': bytes.toList(),
      'gate': ?gate,
    });
    try {
      await transport!.write(bytes);
      _save('written', {'command': command});
    } catch (error) {
      _fault('写出结果未知：$error');
      rethrow;
    }
  }
}

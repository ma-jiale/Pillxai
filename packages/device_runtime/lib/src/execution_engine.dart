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
      state.barcode = null;
      state.barcodeAt = null;
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
  String? _owner(String source, String? value) {
    if (task == null || value == null) return null;
    for (final binding in task!.recognitionBindings) {
      if (binding.source_.toJson() == source && binding.value == value) {
        return binding.residentId;
      }
    }
    if (source == 'rfid' && task!.labels.contains(value)) {
      return task!.plan.residentId;
    }
    return null;
  }

  bool get recognitionConflict {
    final rfid = _owner('rfid', state.uid);
    final barcode = _owner('barcode', state.barcode);
    return rfid != null && barcode != null && rfid != barcode;
  }

  String? get recognitionSource {
    if (!state.connected || task == null || recognitionConflict) return null;
    if (_owner('barcode', state.barcode) == task!.plan.residentId) {
      return 'barcode';
    }
    if (_owner('rfid', state.uid) == task!.plan.residentId) return 'rfid';
    return null;
  }

  bool get recognized => recognitionSource != null;

  void _clearRecognition() {
    state.uid = null;
    state.uidAt = null;
    state.barcode = null;
    state.barcodeAt = null;
  }

  Map<String, dynamic> view() => {
    'terminal_id': journal.terminalId,
    'task': task?.toJson(),
    'state': state.toJson(),
    'observed_uid': observedUid,
    'observed_at': observedAt?.toIso8601String(),
    'raw_lines': rawLines,
    'pending_count': task == null ? 0 : journal.pendingCount(task!.id),
    'recognized': task != null && recognized,
    'recognition_source': recognitionSource,
    'recognition_value': recognitionSource == 'barcode'
        ? state.barcode
        : state.uid,
    'recognition_at':
        (recognitionSource == 'barcode' ? state.barcodeAt : state.uidAt)
            ?.toIso8601String(),
    'recognition_conflict': recognitionConflict,
    'storage_failed': storageFailed,
    'configuration': journal.setting('connection'),
    'claim_intent': journal.setting('claim_intent'),
    'learning_results':
        task?.learningResults.map((r) => r.toJson()).toList() ??
        journal.setting('latest_learning_results') ??
        [],
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
    if (active &&
        [
          ExecutionPhase.completed,
          ExecutionPhase.cancelled,
        ].contains(state.phase)) {
      throw StateError('任务结果尚未同步，请先等待同步完成。');
    }
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
    state.barcode = null;
    state.barcodeAt = null;
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
    _clearRecognition();
    observedUid = null;
    observedAt = null;
    if (active &&
        ![
          ExecutionPhase.deleting,
          ExecutionPhase.completed,
          ExecutionPhase.cancelled,
        ].contains(state.phase)) {
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
    journal.setSetting('latest_learning_results', null);
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

  Future<void> cancelPreparation() async {
    // Consume queued presence changes before deciding whether closing is safe.
    await tick();
    if (!active ||
        state.permitted ||
        task!.state != api.TaskState.claimed ||
        ![
          ExecutionPhase.recognizing,
          ExecutionPhase.ready,
        ].contains(state.phase) ||
        !state.connected ||
        state.pending != null ||
        storageFailed) {
      throw StateError('当前不能关闭准备，请等待设备反馈或核对现场。');
    }
    if (state.trayPresent || state.uid != null || state.barcode != null) {
      throw StateError('轨道上还有药盒，请先取出药盒，再点击关闭。');
    }
    // The explicit close action also abandons an empty opening session.
    // Once a box has appeared, trayPresent stays true until its removal is observed.
    state.phase = ExecutionPhase.closingPreparation;
    state.message = '正在收仓并取消本次准备。';
    await _send('close_preparation');
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
    state.gate ??= batch.parameters.gate.toDouble();
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
      ExecutionPhase.ready,
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

  void acknowledge(
    int sequence, {
    List<api.LearningResult>? learningResults,
    api.TaskState? taskState,
  }) {
    if (task == null) return;
    // A cancelled server receipt can settle an older client's spurious recovery,
    // only after every local event has been accepted. Never discard pending work.
    if (taskState == api.TaskState.cancelled && sequence >= state.sequence) {
      state.phase = ExecutionPhase.cancelled;
    }
    if (learningResults != null) {
      task = task!.copyWith(learningResults: learningResults);
      journal.save(task!, state);
      journal.setSetting(
        'latest_learning_results',
        learningResults.map((r) => r.toJson()).toList(),
      );
    }
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
    _clearRecognition();
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
        state.message = '等待新的药盒识别。';
        _save('recognition_lost');
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
        _clearRecognition();
        observedUid = null;
        observedAt = null;
        _fault('设备通信失败：$error');
        await transport?.close();
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _feedback(DeviceEvent event) async {
    if ([
      ExecutionPhase.cancelled,
      ExecutionPhase.completed,
      ExecutionPhase.deleting,
    ].contains(state.phase)) {
      return;
    }
    if (event.kind == DeviceEventKind.rfid) {
      observedUid = event.uid;
      observedAt = DateTime.now().toUtc();
    }
    if (event.kind == DeviceEventKind.noCard) {
      observedUid = null;
      observedAt = null;
    }
    if (!active) {
      if (event.kind == DeviceEventKind.acknowledged &&
          state.pending == 'open') {
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
    // Opening-related stalls are diagnostic only by the current device policy.
    // Keep raw evidence; parameters, dispensing and closing still fault.
    final ignoredOpeningStall =
        event.kind == DeviceEventKind.stalled &&
        [
          ExecutionPhase.opening,
          ExecutionPhase.changingTray,
          ExecutionPhase.recognizing,
          ExecutionPhase.ready,
          ExecutionPhase.collecting,
        ].contains(state.phase);
    _save('feedback', {
      ...event.toJson(),
      if (ignoredOpeningStall) 'ignored_reason': 'opening_phase',
    });
    if (ignoredOpeningStall) return;
    if (event.kind == DeviceEventKind.initialized) {
      _clearRecognition();
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
    if (state.phase == ExecutionPhase.closingPreparation &&
        [
          DeviceEventKind.rfid,
          DeviceEventKind.barcodeAppeared,
        ].contains(event.kind)) {
      _fault('收仓期间再次识别到药盒，请核对现场。');
      return;
    }
    final collectionCodes = task!.recognitionBindings.where(
      (binding) =>
          binding.source_ == api.RecognitionBindingSource_Enum.barcode &&
          binding.residentId == task!.plan.residentId,
    );
    final collectionCode = collectionCodes.length == 1
        ? collectionCodes.single.value
        : null;
    if (config.barcodeRemovalCloses) {
      if (state.phase == ExecutionPhase.closing &&
          event.kind == DeviceEventKind.barcodeAppeared) {
        _fault('收仓期间再次识别到药盒，请核对现场。');
        return;
      }
      if (state.phase == ExecutionPhase.collecting &&
          !state.cancelRequested &&
          state.pending == null &&
          collectionCode != null &&
          event.kind == DeviceEventKind.barcodeDisappeared &&
          event.barcode == collectionCode) {
        state.trayPresent = false;
        state.absentAt = DateTime.now().toUtc();
        state.phase = ExecutionPhase.closing;
        state.closeDone = false;
        state.readyObserved = false;
        state.message = '药盒已取出，正在收回轨道。';
        await _send('close');
      }
    } else if (config.feedbackVerified) {
      if (event.raw.trim() == config.trayPresentLine) {
        state.trayPresent = true;
        state.absentAt = null;
        if ([
          ExecutionPhase.closing,
          ExecutionPhase.closingPreparation,
        ].contains(state.phase)) {
          _fault('收仓期间检测到药盒重新在轨。');
          return;
        }
      }
      if (event.raw.trim() == config.trayAbsentLine) {
        state.trayPresent = false;
        if ([
          ExecutionPhase.collecting,
          ExecutionPhase.recognizing,
          ExecutionPhase.ready,
        ].contains(state.phase)) {
          state.absentAt ??= DateTime.now().toUtc();
        }
        if ([
          ExecutionPhase.recognizing,
          ExecutionPhase.ready,
        ].contains(state.phase)) {
          _clearRecognition();
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
      ExecutionPhase.starting,
      ExecutionPhase.running,
      ExecutionPhase.paused,
      ExecutionPhase.pausing,
      ExecutionPhase.resuming,
    ].contains(state.phase)) {
      var recognitionChanged = false;
      if (event.kind == DeviceEventKind.rfid) {
        state.trayPresent = true;
        state.absentAt = null;
        state.uid = event.uid;
        state.uidAt = DateTime.now().toUtc();
        recognitionChanged = true;
      } else if (event.kind == DeviceEventKind.noCard) {
        state.uid = null;
        state.uidAt = null;
        recognitionChanged = true;
      } else if (event.kind == DeviceEventKind.barcodeAppeared) {
        state.trayPresent = true;
        state.absentAt = null;
        state.barcode = event.barcode;
        state.barcodeAt = DateTime.now().toUtc();
        recognitionChanged = true;
      } else if (event.kind == DeviceEventKind.barcodeDisappeared &&
          state.barcode == event.barcode) {
        // Explicit preparation cancellation uses observed removal regardless of
        // the separate policy for automatic collection after dispensing.
        if (!state.permitted || config.barcodeRemovalCloses) {
          state.trayPresent = false;
          state.absentAt = DateTime.now().toUtc();
        }
        state.barcode = null;
        state.barcodeAt = null;
        recognitionChanged = true;
      }
      if (recognitionChanged) {
        if ([
          ExecutionPhase.recognizing,
          ExecutionPhase.ready,
        ].contains(state.phase)) {
          state.phase = recognized
              ? ExecutionPhase.ready
              : ExecutionPhase.recognizing;
          state.message = recognitionConflict
              ? 'RFID 与条码归属不一致，请核对药盒。'
              : recognized
              ? '已识别：${task!.plan.residentName}，请核对并开始。'
              : state.uid == null && state.barcode == null
              ? '请放入药盒，等待识别。'
              : '药盒与${task!.plan.residentName}不匹配，请核对并更换正确的药盒。';
        }
        _save(recognized ? 'recognition' : 'recognition_lost', {
          'source': event.barcode != null ? 'barcode' : 'rfid',
          'value': event.barcode ?? event.uid,
          'matched': recognized,
          'conflict': recognitionConflict,
        });
      }
    }
    if (event.kind == DeviceEventKind.acknowledged &&
        state.pending != null &&
        !state.acknowledged) {
      state.acknowledged = true;
      _save('ack', {'command': state.pending});
      if (![
        'open',
        'close',
        'close_preparation',
        'exit',
      ].contains(state.pending)) {
        _commandCompleted();
      }
    } else if (event.kind == DeviceEventKind.actionDone &&
        state.pending != null &&
        state.acknowledged &&
        [
          'open',
          'close',
          'close_preparation',
          'exit',
        ].contains(state.pending)) {
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
        state.gate = null;
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
        if (config.barcodeRemovalCloses) 'source': 'barcode',
        'absent': config.barcodeRemovalCloses
            ? 'DISAPPEARED,$collectionCode'
            : config.trayAbsentLine,
        'ready': config.barcodeRemovalCloses ? 'ACK,DONE' : config.readyLine,
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
        _clearRecognition();
        state.absentAt = null;
        if (state.openPurpose == 'collect') {
          state.phase = ExecutionPhase.collecting;
          state.trayPresent = true;
          state.message = task!.device.configuration.barcodeRemovalCloses
              ? '本次药物已摆完，请取出药盒，轨道将自动收回。'
              : '药物处理结束，请取出药盒。等待有效离轨及就绪反馈。';
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
      case 'close_preparation':
        _save('command_done', {'command': command});
        _clearRecognition();
        state.phase = ExecutionPhase.cancelled;
        state.message = '轨道已收回，本次准备已取消。';
        _save('cancelled', {'physical_scene_safe': true});
        return;
      case 'close':
        state.closeDone = true;
        if (task!.device.configuration.barcodeRemovalCloses) {
          state.readyObserved = true;
        }
      case 'manual_gate':
        state.message = '开口设置已下发，请核对现场。';
    }
    _save('command_done', {'command': command});
  }

  Future<void> _send(String command, {double? gate}) async {
    if (command == 'matrix' && !recognized) {
      _fault('下发矩阵前药盒识别已失效，请核对现场。');
      return;
    }
    if (storageFailed || !state.connected || state.pending != null) {
      throw StateError('设备未连接、命令未确认或保存失败。');
    }
    final Uint8List bytes = switch (command) {
      'open' => Stm32Commands.openTray(),
      'close' || 'close_preparation' => Stm32Commands.closeTray(),
      'turntable' => Stm32Commands.setTurntable(
        batch.parameters.turntable.toDouble(),
      ),
      'gate' => Stm32Commands.setGate(
        state.gate ?? batch.parameters.gate.toDouble(),
      ),
      'matrix' => Stm32Commands.matrix(batch.matrix),
      'pause' || 'stop_cancel' => Stm32Commands.stop(),
      'resume' => Stm32Commands.resume(),
      'exit' => Stm32Commands.exitMedicine(),
      'manual_gate' => Stm32Commands.setGate(gate!),
      _ => throw ArgumentError(command),
    };
    state.pending = command;
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
      if (command == 'manual_gate') {
        state.gate = gate;
        _save('manual_gate_written', {'gate': gate});
      }
      if (command == 'matrix') {
        _save('batch_started', {
          'gate': state.gate ?? batch.parameters.gate.toDouble(),
          'turntable': batch.parameters.turntable,
          'parameter_revision': batch.parameters.revision,
        });
      }
    } catch (error) {
      _fault('写出结果未知：$error');
      rethrow;
    }
  }
}

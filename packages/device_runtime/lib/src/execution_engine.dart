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
    this.ackTimeout = const Duration(milliseconds: 200),
    this.now = DateTime.now,
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
    } else if (journal.setting('identification') != null) {
      state.openPurpose = 'identify';
      state.phase = ExecutionPhase.recovery;
      state.message = '药盒识别曾被中断，请重启分药机并重新连接后再开仓。';
    }
    state.stalledMotors = {
      ...state.stalledMotors,
      for (final notice in stallNotices) notice['motor'] as int,
    }.toList();
  }
  final ExecutionJournal journal;
  final Duration commandTimeout;
  final Duration ackTimeout;
  final DateTime Function() now;
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
  Uint8List? _pendingBytes;
  int _sendAttempts = 0;
  bool _disconnectHandled = false;
  String? _releasingStallNotice;
  List<Map<String, dynamic>> get stallNotices => [
    for (final value in journal.setting('stall_notices') as List? ?? [])
      Map<String, dynamic>.from(value as Map),
  ];
  bool get _releasingStall =>
      state.pending == 'release_stall_2' || state.pending == 'release_stall_3';
  bool _polling = false;
  bool storageFailed = false;

  api.BatchPlan get batch => task!.batches[state.batch];
  bool get active => task != null;
  bool get identifying => !active && state.openPurpose == 'identify';
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
    'can_confirm_count_review': canConfirmCountReview,
    'identifying': identifying,
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
    'disconnect_notice': journal.setting('disconnect_notice'),
    'stall_notices': stallNotices,
    'learning_results':
        task?.learningResults.map((r) => r.toJson()).toList() ??
        journal.setting('latest_learning_results') ??
        [],
  };

  void _save(String kind, [Map<String, dynamic>? detail]) {
    try {
      if (task == null) {
        journal.setSetting(
          'identification',
          identifying ? state.toJson() : null,
        );
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
    // Establishing a connection (including its initial drain) is not an
    // established-session loss, even if the transport reports EOF/IOException.
    late final Uint8List buffered;
    try {
      await next.open();
      buffered = await next.read();
    } catch (_) {
      state.connected = false;
      await next.close();
      transport = null;
      rethrow;
    }
    state.connected = true;
    _disconnectHandled = false;
    journal.setSetting('stall_notices', [
      for (final notice in stallNotices) {...notice, 'seen': false},
    ]);
    observedUid = null;
    observedAt = null;
    state.uid = null;
    state.uidAt = null;
    state.barcode = null;
    state.barcodeAt = null;
    if (!active) {
      state.openPurpose = 'initial';
      state.phase = ExecutionPhase.idle;
      state.pending = null;
    }
    _save('connected');
    // Old buffered replies cannot authorize a command.
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
    await tick();
    final fromScan = identifying && state.phase == ExecutionPhase.recognizing;
    if (active ||
        state.stalledMotors.isNotEmpty ||
        !state.connected ||
        storageFailed ||
        state.pending != null ||
        (state.phase != ExecutionPhase.idle && !fromScan)) {
      throw StateError('本机未就绪或已有任务。');
    }
    if (claimed.terminalId != journal.terminalId ||
        claimed.state != api.TaskState.claimed) {
      throw StateError('任务归属或阶段不正确。');
    }
    task = claimed;
    journal.setSetting('latest_learning_results', null);
    if (fromScan) {
      state.openPurpose = 'initial';
      state.phase = recognized
          ? ExecutionPhase.ready
          : ExecutionPhase.recognizing;
      state.message = recognized
          ? '已识别：${claimed.plan.residentName}，请核对并开始。'
          : '药盒已变化，请重新核对当前长者的药盒。';
    } else {
      state = ExecutionState()
        ..connected = true
        ..phase = ExecutionPhase.opening;
    }
    _save('claimed');
    journal.setSetting('identification', null);
    journal.setSetting('claim_intent', null);
    if (!fromScan) await _send('open');
  }

  Future<void> openForIdentification() async {
    if (active ||
        identifying ||
        state.phase != ExecutionPhase.idle ||
        state.pending != null ||
        !state.connected ||
        state.stalledMotors.isNotEmpty ||
        storageFailed ||
        journal.setting('claim_intent') != null) {
      throw StateError('请先完成当前任务并连接就绪的摆药机。');
    }
    _clearRecognition();
    state.openPurpose = 'identify';
    state.phase = ExecutionPhase.opening;
    state.trayPresent = false;
    state.absentAt = null;
    state.message = '正在开仓，请等待完成后放入药盒。';
    await _send('open');
  }

  Future<void> closeIdentification() async {
    await tick();
    if (!identifying ||
        state.phase != ExecutionPhase.recognizing ||
        state.pending != null ||
        !state.connected ||
        storageFailed) {
      throw StateError('请等待开仓完成；状态未知时请重启分药机并重新连接。');
    }
    if (state.trayPresent || state.uid != null || state.barcode != null) {
      throw StateError('请先取出药盒，再关闭。');
    }
    if (journal.setting('claim_intent') != null) {
      throw StateError('领取结果尚未核对，请先恢复或清除领取请求。');
    }
    state.phase = ExecutionPhase.closingPreparation;
    state.message = '正在收回轨道。';
    await _send('close_preparation');
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
    await tick();
    if (state.phase != ExecutionPhase.ready ||
        state.stalledMotors.isNotEmpty ||
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
    if (state.stalledMotors.isNotEmpty) {
      throw StateError('请先排查并解除电机堵转。');
    }
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

  void _checkBatch(String taskId, int batchIndex) {
    if (task?.id != taskId || state.batch != batchIndex) {
      throw StateError('当前药物已变化，请重新操作。');
    }
  }

  Future<void> reviewSkip(String taskId, int batchIndex) async {
    _checkBatch(taskId, batchIndex);
    if (task!.skipProtocol != 1) throw StateError('请更新服务端后领取新任务以使用跳过。');
    if (![
          ExecutionPhase.running,
          ExecutionPhase.paused,
        ].contains(state.phase) ||
        state.pending != null ||
        !state.connected) {
      throw StateError('请等待当前设备动作完成后再跳过。');
    }
    state.skipWasRunning = state.phase == ExecutionPhase.running;
    state.phase = ExecutionPhase.reviewingSkip;
    _save('skip_review');
    if (state.skipWasRunning) await _send('pause_skip');
  }

  Future<void> cancelSkip(String taskId, int batchIndex) async {
    _checkBatch(taskId, batchIndex);
    if (state.phase != ExecutionPhase.reviewingSkip || state.pending != null) {
      throw StateError('请等待停转确认，或核对设备状态。');
    }
    state.phase = ExecutionPhase.paused;
    _save('skip_review_cancelled');
    if (state.skipWasRunning) await resume();
  }

  Future<void> skip(
    String taskId,
    int batchIndex, {
    required bool allRemaining,
    required bool manual,
  }) async {
    _checkBatch(taskId, batchIndex);
    if (state.phase != ExecutionPhase.reviewingSkip ||
        state.pending != null ||
        !state.connected ||
        (allRemaining && manual)) {
      throw StateError('请等待停转确认并核对跳过范围。');
    }
    state.skipRequest = {'all_remaining': allRemaining, 'manual': manual};
    state.phase = ExecutionPhase.skipping;
    state.message = '正在停止并退出当前药物，请勿投料。';
    _save('skip_requested', state.skipRequest);
    await _send('stop_skip');
  }

  Future<void> beginNextBatch(String taskId, int batchIndex) async {
    _checkBatch(taskId, batchIndex);
    if (state.phase != ExecutionPhase.awaitingNextBatch ||
        state.pending != null) {
      throw StateError('当前不能开始下一药。');
    }
    await _beginBatch();
  }

  bool get canConfirmCountReview {
    if (state.phase != ExecutionPhase.reviewingCount ||
        task == null ||
        !state.connected ||
        storageFailed ||
        state.pending != null ||
        state.stalledMotors.isNotEmpty ||
        recognitionConflict ||
        (state.barcode != null &&
            _owner('barcode', state.barcode) != task!.plan.residentId)) {
      return false;
    }
    final next = task!.batches.elementAtOrNull(state.batch + 1);
    if (next == null) return state.uid == null || recognized;
    return state.trayPresent &&
        recognized &&
        (next.tray == batch.tray || state.reviewTrayRemoved);
  }

  Future<void> confirmCountReview(String taskId, int batchIndex) async {
    await tick();
    _checkBatch(taskId, batchIndex);
    if (!canConfirmCountReview) {
      throw StateError('请等待开仓完成并核对所需药盒。');
    }
    task = task!.copyWith(manualBatches: [...task!.manualBatches, batchIndex]);
    final last = batchIndex + 1 == task!.batches.length;
    if (last) {
      state.openPurpose = 'collect';
      state.phase = ExecutionPhase.collecting;
      state.message = '本药已人工核对，请取出药盒。';
    }
    _save('skip_completed', {
      'manual': true,
      'all_remaining': false,
      'source': 'counter_review',
    });
    if (last) {
      if (!state.trayPresent &&
          state.absentAt != null &&
          task!.device.configuration.barcodeRemovalCloses) {
        state.phase = ExecutionPhase.closing;
        await _send('close');
      }
    } else {
      state.batch++;
      state.gate = null;
      state.openPurpose = 'initial';
      await _beginBatch();
    }
  }

  Future<void> retryCollection(String taskId, int batchIndex) async {
    _checkBatch(taskId, batchIndex);
    if (state.phase != ExecutionPhase.recovery ||
        state.openPurpose != 'collect' ||
        state.matrixIssued ||
        state.skipRequest != null ||
        state.cancelRequested ||
        state.pending != null ||
        !state.connected) {
      throw StateError('药物结果或设备状态尚未确认，不能重试开仓。');
    }
    state.phase = ExecutionPhase.opening;
    await _send('open');
  }

  void _advanceBatch({bool allRemaining = false, bool paused = false}) {
    state.matrixIssued = false;
    if (allRemaining || state.batch == task!.batches.length - 1) {
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
        _clearRecognition();
        _nextCommand = 'open';
      } else if (paused) {
        state.phase = ExecutionPhase.awaitingNextBatch;
        state.message = '已跳过，保持暂停。确认下一药后继续。';
      } else {
        state.phase = ExecutionPhase.starting;
        _nextCommand = 'turntable';
      }
    }
    _save('next_stage');
  }

  Future<void> resume({bool physicalProgressRetained = false}) async {
    if (state.stalledMotors.isNotEmpty ||
        state.openPurpose == 'counter_review' ||
        state.skipRequest != null ||
        state.cancelRequested ||
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

  Future<void> releaseStall(int motor) async {
    if (!state.stalledMotors.contains(motor) || ![2, 3].contains(motor)) {
      throw StateError('没有对应的待解除堵转。');
    }
    _releasingStallNotice =
        stallNotices
                .where((notice) => notice['motor'] == motor)
                .firstOrNull?['id']
            as String?;
    await _send('release_stall_$motor');
  }

  Future<void> confirmStallNotice(String id, {required bool release}) async {
    final notice = stallNotices
        .where((notice) => notice['id'] == id)
        .firstOrNull;
    if (notice == null) throw StateError('堵转状态已变化，请重新核对。');
    if (release) await releaseStall(notice['motor'] as int);
    journal.setSetting('stall_notices', [
      for (final current in stallNotices)
        if (current['id'] == id) {...current, 'seen': true} else current,
    ]);
  }

  void _reportStall(int motor) {
    final notices = stallNotices;
    final previous = notices
        .where((notice) => notice['motor'] == motor)
        .firstOrNull;
    // Repeated reports share one visible alert. A new report during release
    // gets a new identity, so a delayed ACK cannot clear the new blockage.
    final renew =
        previous == null || previous['seen'] == true || _releasingStall;
    journal.setSetting('stall_notices', [
      for (final notice in notices)
        if (notice['motor'] != motor) notice,
      if (!renew)
        previous
      else
        {
          'id': newExecutionId(),
          'motor': motor,
          'seen': false,
          'owner_id': task?.ownerId,
          'task_id': task?.id,
        },
    ]);
    if (!state.stalledMotors.contains(motor)) state.stalledMotors.add(motor);
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

  Future<void> requestDiscard({bool disconnected = false}) async {
    if (state.phase == ExecutionPhase.deleting) return;
    if (!active ||
        [
          ExecutionPhase.completed,
          ExecutionPhase.cancelled,
        ].contains(state.phase)) {
      throw StateError('只能删除当前未结束任务。');
    }
    if (disconnected) {
      state = ExecutionState()..sequence = state.sequence;
    }
    state.phase = ExecutionPhase.deleting;
    state.disconnectedDiscard = disconnected;
    state.connected = false;
    state.pending = null;
    _nextCommand = null;
    state.message = disconnected
        ? '分药机连接已断开，本次任务已终止，正在清理任务。网络恢复后自动重试。'
        : '正在结束并删除，等待中央确认。';
    _save(disconnected ? 'disconnect_delete_intent' : 'delete_intent');
    await transport?.close();
    // No physical commands: disconnection cannot prove that the motor stopped.
  }

  Future<void> _deviceDisconnected() async {
    if (_disconnectHandled) return;
    _disconnectHandled = true;
    state.connected = false;
    _clearRecognition();
    observedUid = null;
    observedAt = null;
    _deadline = null;
    _pendingBytes = null;
    _nextCommand = null;
    decoder = FeedbackDecoder();
    journal.setSetting('stall_notices', null);
    if (active) {
      await requestDiscard(disconnected: true);
    } else {
      state = ExecutionState()..message = '摆药机连接已断开，请重启分药机后重新连接。';
      journal.setSetting('identification', null);
      journal.setSetting('disconnect_notice', {
        'task_id': newExecutionId(),
        'owner_id': null,
      });
      await transport?.close();
    }
  }

  void finishDiscard() {
    if (state.phase != ExecutionPhase.deleting) throw StateError('没有删除意图。');
    journal.discard(task!.id);
    journal.setSetting('stall_notices', null);
    task = null;
    state = ExecutionState();
    rawLines.clear();
  }

  void acknowledge(
    int sequence, {
    List<api.LearningResult>? learningResults,
    api.TaskState? taskState,
  }) {
    if (task == null || state.phase == ExecutionPhase.deleting) return;
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
    _deadline = null;
    _pendingBytes = null;
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
          !now().isBefore(_deadline!)) {
        if (state.acknowledged) {
          _fault('等待 DONE 超时，动作失败，请核对现场。');
        } else if (_releasingStall) {
          _fault('解除堵转未收到 ACK，解除尚未确认；连接与接收保持。');
        } else if (state.phase == ExecutionPhase.openingForReview &&
            !['stop_review', 'exit', 'open'].contains(state.pending)) {
          _fault('机器报错前的命令尚未确认，不能重发或继续开仓。');
        } else if (_sendAttempts < 6) {
          await _writePending();
        } else {
          _save('command_no_response', {
            'command': state.pending,
            'attempts': _sendAttempts,
          });
          await _deviceDisconnected();
          return;
        }
      }
      if (state.phase == ExecutionPhase.ready && !recognized) {
        state.phase = ExecutionPhase.recognizing;
        state.message = '等待新的药盒识别。';
        _save('recognition_lost');
      }
      if (state.phase == ExecutionPhase.collecting &&
          state.stalledMotors.isEmpty &&
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
    } on DeviceDisconnected {
      await _deviceDisconnected();
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
    if (event.kind == DeviceEventKind.stalled) {
      _reportStall(event.count!);
      if (!active) _save('feedback', event.toJson());
    }
    if (!active) {
      if (_releasingStall && event.kind == DeviceEventKind.acknowledged) {
        state.acknowledged = true;
        _commandCompleted();
        return;
      }
      if (event.kind == DeviceEventKind.acknowledged &&
          ['open', 'close_preparation'].contains(state.pending) &&
          !state.acknowledged) {
        state.acknowledged = true;
        _deadline = now().add(commandTimeout);
      }
      if (event.kind == DeviceEventKind.actionDone &&
          ['open', 'close_preparation'].contains(state.pending) &&
          state.acknowledged) {
        final closing = state.pending == 'close_preparation';
        state.pending = null;
        _deadline = null;
        _pendingBytes = null;
        _clearRecognition();
        if (closing) state.openPurpose = 'initial';
        state.phase = identifying
            ? ExecutionPhase.recognizing
            : ExecutionPhase.idle;
        state.message = identifying ? '请放入药盒，扫描条码识别长者。' : '设备动作已完成。';
        _save('command_done');
      }
      if (identifying && state.phase == ExecutionPhase.recognizing) {
        if (event.kind == DeviceEventKind.barcodeAppeared) {
          state.barcode = event.barcode;
          state.barcodeAt = now().toUtc();
          state.trayPresent = true;
          state.absentAt = null;
        } else if (event.kind == DeviceEventKind.barcodeDisappeared &&
            event.barcode == state.barcode) {
          _clearRecognition();
          state.trayPresent = false;
          state.absentAt = now().toUtc();
        } else if (event.kind == DeviceEventKind.rfid) {
          state.uid = event.uid;
          state.uidAt = now().toUtc();
          state.trayPresent = true;
        } else if (event.kind == DeviceEventKind.noCard) {
          state.uid = null;
          state.uidAt = null;
        }
        _save('identification_feedback', event.toJson());
      }
      return;
    }
    // Opening feedback keeps its ACK/DONE tracking; the alert blocks a new
    // batch until staff handle the reported motor. Dispensing still faults.
    final ignoredOpeningStall =
        event.kind == DeviceEventKind.stalled &&
        ([
              ExecutionPhase.opening,
              ExecutionPhase.changingTray,
              ExecutionPhase.recognizing,
              ExecutionPhase.ready,
              ExecutionPhase.collecting,
              ExecutionPhase.reviewingCount,
            ].contains(state.phase) ||
            (state.phase == ExecutionPhase.openingForReview &&
                !state.matrixIssued));
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
    if (event.kind == DeviceEventKind.counterError) {
      if (state.counterErrorBatch == state.batch) return;
      if (state.matrixIssued &&
          [
            ExecutionPhase.starting,
            ExecutionPhase.running,
            ExecutionPhase.paused,
            ExecutionPhase.pausing,
            ExecutionPhase.resuming,
            ExecutionPhase.reviewingSkip,
          ].contains(state.phase)) {
        state.counterErrorBatch = state.batch;
        state.openPurpose = 'counter_review';
        state.phase = ExecutionPhase.openingForReview;
        state.reviewTrayRemoved = false;
        state.message = '当前药物摆药错误，请停止投料。正在停转。';
        if (state.pending == null) _nextCommand = 'stop_review';
        _save('counter_review_requested');
        return;
      }
      _fault('收到异常反馈：${event.raw}');
      return;
    }
    if ([
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
    final reviewing = state.phase == ExecutionPhase.reviewingCount;
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
        if (state.stalledMotors.isNotEmpty) {
          _save('collection_blocked_by_stall');
          return;
        }
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
          ExecutionPhase.reviewingCount,
          ExecutionPhase.recognizing,
          ExecutionPhase.ready,
        ].contains(state.phase)) {
          state.absentAt ??= DateTime.now().toUtc();
        }
        if (reviewing) {
          state.reviewTrayRemoved = true;
          _clearRecognition();
          _save('review_tray_removed');
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
      ExecutionPhase.reviewingSkip,
      ExecutionPhase.reviewingCount,
      ExecutionPhase.awaitingNextBatch,
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
          (state.barcode == event.barcode ||
              (reviewing &&
                  state.barcode == null &&
                  event.barcode == collectionCode))) {
        // Explicit preparation cancellation uses observed removal regardless of
        // the separate policy for automatic collection after dispensing.
        if (!state.permitted ||
            (config.barcodeRemovalCloses &&
                (!reviewing || event.barcode == collectionCode))) {
          state.trayPresent = false;
          state.absentAt = DateTime.now().toUtc();
          if (reviewing) {
            state.reviewTrayRemoved = true;
            _clearRecognition();
          }
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
      _deadline = now().add(commandTimeout);
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
          ExecutionPhase.reviewingSkip,
          ExecutionPhase.skipping,
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
      _advanceBatch();
    }
    if (event.kind == DeviceEventKind.batchFinished &&
        state.matrixIssued &&
        [
          ExecutionPhase.paused,
          ExecutionPhase.pausing,
          ExecutionPhase.resuming,
          ExecutionPhase.reviewingSkip,
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
    _pendingBytes = null;
    if (state.cancelRequested && command != 'stop_cancel') {
      _nextCommand = 'stop_cancel';
      _save('command_done', {'command': command});
      return;
    }
    // Finish any already-issued parameter, matrix or pause command before
    // sending stop. An unnumbered ACK must only settle its original command.
    if (state.phase == ExecutionPhase.openingForReview &&
        !['stop_review', 'exit', 'open'].contains(command)) {
      _nextCommand = 'stop_review';
      _save('command_done', {'command': command});
      return;
    }
    switch (command) {
      case 'open':
        _clearRecognition();
        state.absentAt = null;
        if (state.openPurpose == 'counter_review') {
          state.phase = ExecutionPhase.reviewingCount;
          state.trayPresent = true;
          state.message = '请逐格核对当前药物并按计划补齐。';
        } else if (state.openPurpose == 'collect') {
          state.phase = ExecutionPhase.collecting;
          state.trayPresent = true;
          state.message = task!.device.configuration.barcodeRemovalCloses
              ? '本次药物已处理，请取出药盒，轨道将自动收回。'
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
      case 'pause_skip':
        state.message = '已暂停，请核对跳过范围。';
      case 'stop_skip':
        _nextCommand = 'exit';
      case 'stop_review':
        state.message = '已收到停转确认，正在退出当前药物。';
        _nextCommand = 'exit';
      case 'exit':
        if (state.openPurpose == 'counter_review') {
          state.matrixIssued = false;
          state.message = '正在弹出药盒，请等待开仓完成。';
          _nextCommand = 'open';
          break;
        }
        _save('command_done', {'command': command});
        final request = state.skipRequest!;
        final skipped = request['all_remaining'] == true
            ? [for (var i = state.batch; i < task!.batches.length; i++) i]
            : request['manual'] == true
            ? <int>[]
            : [state.batch];
        task = task!.copyWith(
          skippedBatches: [...task!.skippedBatches, ...skipped],
          manualBatches: [
            ...task!.manualBatches,
            if (request['manual'] == true) state.batch,
          ],
        );
        _save('skip_completed', request);
        state.skipRequest = null;
        _advanceBatch(
          allRemaining: request['all_remaining'] == true,
          paused: !state.skipWasRunning,
        );
        return;
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
      case 'release_stall_2':
      case 'release_stall_3':
        final motor = int.parse(command.split('_').last);
        final notice = stallNotices
            .where((notice) => notice['motor'] == motor)
            .firstOrNull;
        if (notice?['id'] != _releasingStallNotice) {
          state.message = '机器再次报告堵转，请重新排查。';
          break;
        }
        state.stalledMotors.remove(motor);
        journal.setSetting('stall_notices', [
          for (final item in stallNotices)
            if (item['motor'] != motor) item,
        ]);
        state.message = state.stalledMotors.isNotEmpty
            ? '已收到解除堵转 ACK，仍有其他电机待处理。'
            : state.phase == ExecutionPhase.reviewingCount
            ? '堵转已解除，请逐格核对当前药物并按计划补齐。'
            : '已收到解除堵转 ACK，请核对现场后继续原批次。';
    }
    _save('command_done', {'command': command});
  }

  Future<void> _send(String command, {double? gate}) async {
    if ([
      ExecutionPhase.deleting,
      ExecutionPhase.completed,
      ExecutionPhase.cancelled,
    ].contains(state.phase)) {
      throw StateError('任务已结束，不能发送设备命令。');
    }
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
      'pause' ||
      'stop_cancel' ||
      'pause_skip' ||
      'stop_review' ||
      'stop_skip' => Stm32Commands.stop(),
      'resume' => Stm32Commands.resume(),
      'exit' => Stm32Commands.exitMedicine(),
      'manual_gate' => Stm32Commands.setGate(gate!),
      'release_stall_2' => Stm32Commands.releaseStall(2),
      'release_stall_3' => Stm32Commands.releaseStall(3),
      _ => throw ArgumentError(command),
    };
    state.pending = command;
    state.acknowledged = false;
    if (command == 'matrix') state.matrixIssued = true;
    _pendingBytes = bytes;
    _sendAttempts = 0;
    await _writePending(gate: gate);
  }

  Future<void> _writePending({double? gate}) async {
    final command = state.pending!;
    final bytes = _pendingBytes!;
    final retry = _sendAttempts > 0;
    _sendAttempts++;
    _save(retry ? 'retry_write_intent' : 'write_intent', {
      'command': command,
      'bytes': bytes.toList(),
      'attempt': _sendAttempts,
      'gate': ?gate,
    });
    try {
      await transport!.write(bytes);
      _deadline = now().add(ackTimeout);
      _save(retry ? 'retry_written' : 'written', {
        'command': command,
        'attempt': _sendAttempts,
      });
      if (!retry && command == 'manual_gate') {
        state.gate = gate;
        _save('manual_gate_written', {'gate': gate});
      }
      if (!retry && command == 'matrix') {
        _save('batch_started', {
          'gate': state.gate ?? batch.parameters.gate.toDouble(),
          'turntable': batch.parameters.turntable,
          'parameter_revision': batch.parameters.revision,
        });
      }
    } on DeviceDisconnected {
      await _deviceDisconnected();
      rethrow;
    } catch (error) {
      _fault('写出结果未知：$error');
      rethrow;
    }
  }
}

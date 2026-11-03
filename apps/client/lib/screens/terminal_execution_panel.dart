import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;

import '../data/terminal_controller.dart';
import '../widgets/execution_medicine_card.dart';
import '../widgets/dispensing_medicine_cards.dart';
import '../widgets/dispenser_icon.dart';
import 'skip_medicine_dialog.dart';
import 'motor_stall_dialog.dart';

class TerminalExecutionPanel extends StatelessWidget {
  const TerminalExecutionPanel({
    super.key,
    required this.terminal,
    this.residentAvatar,
  });
  final String? residentAvatar;
  final TerminalController terminal;

  Future<bool> confirm(BuildContext context, String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: terminal,
    builder: (context, _) {
      final task = terminal.task;
      final batch = terminal.batch;
      final phase = terminal.phase;
      final preparing =
          [
            'opening',
            'recognizing',
            'ready',
            'changingTray',
            'closingPreparation',
          ].contains(phase) ||
          terminal.state['permitted'] != true;
      final waiting = [
        'collecting',
        'closing',
        'completed',
        'cancelled',
        'deleting',
      ].contains(phase);
      final simulator =
          task?.device.configuration.mode == api.DeviceMode.simulator;
      return Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task == null) ...[
              const Text('领取结果待恢复'),
              const Text('请连接原设备后恢复领取结果；结果未核对前不创建第二份任务。'),
              Wrap(
                spacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: terminal.busy
                        ? null
                        : () => terminal.run(terminal.recoverClaim),
                    child: const Text('恢复领取结果'),
                  ),
                  TextButton(
                    onPressed: terminal.busy
                        ? null
                        : terminal.forgetRejectedClaim,
                    child: const Text('核对未领取并清除请求'),
                  ),
                ],
              ),
            ] else ...[
              DispensingIdentity(
                avatar: residentAvatar,
                name: task.plan.residentName,
                bed: task.plan.bed,
                stage: preparing
                    ? '药盒识别'
                    : batch == null
                    ? ''
                    : '${batch.purpose} · 第 ${batch.index + 1} / ${task.batches.length} 药',
              ),
              const SizedBox(height: 38),
              if (simulator)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('模拟演练'),
                ),
              if (!waiting && !preparing && batch != null) ...[
                ExecutionMedicineCard(
                  batch: batch,
                  count: terminal.count,
                  stage: terminal.state['message'] as String? ?? '',
                  next: batch.index + 1 < task.batches.length
                      ? task.batches[batch.index + 1]
                      : null,
                ),
                const SizedBox(height: 24),
              ],
              if (waiting) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: DispenserIcon(size: 64),
                ),
                const SizedBox(height: 16),
                Text(
                  phase == 'closing'
                      ? '正在收回轨道'
                      : phase == 'collecting'
                      ? '请取出药盒'
                      : phase == 'completed'
                      ? (task.skippedBatches.isEmpty ? '本次已完成' : '本次已结束，有药物未完成')
                      : '本次已结束',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (preparing && !waiting) ...[
                Text(
                  '请核对${task.plan.residentName}的药盒',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (waiting || preparing || batch == null)
                Text(terminal.state['message'] as String? ?? ''),
              if (!terminal.ownTask) const Text('当前任务属于其他账号，请使用原账号登录。'),
              if (!terminal.ownTask) const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (preparing && terminal.state['permitted'] != true)
                    FilledButton(
                      onPressed:
                          terminal.busy ||
                              !terminal.ownTask ||
                              !terminal.connected ||
                              !['recognizing', 'ready'].contains(phase)
                          ? null
                          : () => terminal.action('cancel_preparation'),
                      child: const Text('关闭准备'),
                    ),
                  if (phase == 'ready')
                    DispensingPrimaryButton(
                      label: terminal.state['permitted'] == true
                          ? '已换好，继续'
                          : '开始摆药',
                      icon: Icons.play_arrow_rounded,
                      onPressed:
                          terminal.busy ||
                              !terminal.recognized ||
                              (terminal.state['stalled_motors'] as List? ?? [])
                                  .isNotEmpty ||
                              !terminal.ownTask
                          ? null
                          : terminal.start,
                    ),
                  if (phase == 'running')
                    DispensingPrimaryButton(
                      label: '暂停',
                      icon: Icons.pause_rounded,
                      onPressed: terminal.busy
                          ? null
                          : () => terminal.action('pause'),
                    ),
                  if (phase == 'paused')
                    DispensingPrimaryButton(
                      label: '继续',
                      icon: Icons.play_arrow_rounded,
                      onPressed: terminal.busy
                          ? null
                          : () => terminal.action('resume'),
                    ),
                  if (phase == 'awaitingNextBatch' && batch != null)
                    DispensingPrimaryButton(
                      label: '继续',
                      icon: Icons.play_arrow_rounded,
                      onPressed: terminal.busy
                          ? null
                          : () => terminal.action('begin_next', {
                              'task_id': task.id,
                              'batch': batch.index,
                            }),
                    ),
                  if (task.skipProtocol == 1 &&
                      ['running', 'paused', 'reviewingSkip'].contains(phase) &&
                      batch != null)
                    OutlinedButton(
                      key: const ValueKey('skip-medicine'),
                      onPressed:
                          terminal.busy ||
                              !terminal.ownTask ||
                              !terminal.connected ||
                              terminal.state['pending'] != null
                          ? null
                          : () => showDialog<void>(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => SkipMedicineDialog(
                                terminal: terminal,
                                taskId: task.id,
                                batch: batch.index,
                                name: batch.name,
                              ),
                            ),
                      child: const Text('跳过'),
                    ),
                  if ((terminal.state['stalled_motors'] as List? ?? [])
                      .isNotEmpty) ...[
                    for (final motor
                        in terminal.state['stalled_motors'] as List? ?? [])
                      OutlinedButton(
                        onPressed:
                            terminal.busy ||
                                !terminal.ownTask ||
                                !terminal.connected ||
                                terminal.state['pending'] != null
                            ? null
                            : () {
                                final notice =
                                    (terminal.view['stall_notices'] as List? ??
                                            [])
                                        .cast<Map>()
                                        .where(
                                          (notice) => notice['motor'] == motor,
                                        )
                                        .firstOrNull;
                                if (notice != null) {
                                  showDialog<void>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) => MotorStallDialog(
                                      terminal: terminal,
                                      notice: Map<String, dynamic>.from(notice),
                                    ),
                                  );
                                }
                              },
                        child: Text('处理 $motor 号电机堵转'),
                      ),
                  ],
                  if (phase == 'recovery') ...[
                    if (terminal.state['open_purpose'] == 'collect' &&
                        terminal.state['matrix_issued'] != true &&
                        terminal.state['skip_request'] == null &&
                        batch != null)
                      OutlinedButton(
                        onPressed: terminal.busy || !terminal.connected
                            ? null
                            : () async {
                                if (await confirm(
                                  context,
                                  '重试开仓取盒',
                                  '请停止投料，确认机器已停稳。仅重试开仓，保留已有结果。',
                                )) {
                                  await terminal.action('retry_collection', {
                                    'task_id': task.id,
                                    'batch': batch.index,
                                  });
                                }
                              },
                        child: const Text('重试开仓取盒'),
                      ),
                    OutlinedButton(
                      onPressed: terminal.connected || terminal.busy
                          ? null
                          : () => terminal.action('connect'),
                      child: const Text('尝试重连'),
                    ),
                    FilledButton(
                      onPressed:
                          !terminal.connected ||
                              terminal.busy ||
                              (terminal.state['stalled_motors'] as List? ?? [])
                                  .isNotEmpty ||
                              terminal.state['reset_observed'] == true ||
                              terminal.state['open_purpose'] == 'counter_review' ||
                              terminal.state['matrix_issued'] != true
                          ? null
                          : () async {
                              if (await confirm(
                                context,
                                '继续原批次',
                                '请确认：机器未断电或复位、原药盒和药物未更换，且原批次进度仍保留。软件只发送恢复命令，不重发矩阵。',
                              )) {
                                await terminal.action('resume', {
                                  'confirmed': true,
                                });
                              }
                            },
                      child: const Text('核对后继续分药'),
                    ),
                  ],
                  if (simulator && phase == 'collecting')
                    OutlinedButton(
                      onPressed: () => terminal.action('sim_remove'),
                      child: const Text('模拟取出药盒'),
                    ),
                  if (simulator && phase == 'recognizing')
                    OutlinedButton(
                      onPressed: () => terminal.action('sim_insert', {
                        'uid': task.labels.first,
                      }),
                      child: const Text('模拟放入本人药盒'),
                    ),
                  if (phase == 'awaitingSafeConfirmation')
                    FilledButton(
                      onPressed: terminal.busy
                          ? null
                          : () async {
                              if (await confirm(
                                context,
                                '结束本次',
                                '请确认机器已安全停稳，药盒和剩余药物已妥善处理。本次不计入完成覆盖，保留核对记录。',
                              )) {
                                await terminal.action('cancel');
                              }
                            },
                      child: const Text('现场已处理，结束本次'),
                    ),
                  if (phase == 'recovery' ||
                      phase == 'awaitingSafeConfirmation')
                    TextButton(
                      onPressed: terminal.busy
                          ? null
                          : () async {
                              if (await confirm(
                                context,
                                '结束此次分药（不记录）',
                                '请先停止投料，确认机器安全停稳，并妥善处理药盒和药物。确认后删除本次任务及全部关联记录，不发送机器命令。',
                              )) {
                                await terminal.action('discard');
                              }
                            },
                      child: const Text('结束此次分药（不记录）'),
                    ),
                  if (['ready', 'running', 'paused'].contains(phase) &&
                      batch != null)
                    OutlinedButton.icon(
                      key: const ValueKey('adjust-opening'),
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('调整开口'),
                      onPressed: !terminal.ownTask
                          ? null
                          : () => _adjustOpening(context, task, batch),
                    ),
                ],
              ),
            ],
            if (terminal.pending > 0) const Text('记录已保存在本机，正在同步…'),
            for (final result
                in (terminal.view['learning_results'] as List? ?? []))
              if ((result as Map)['status'] == 'conflict')
                Text(result['message'] as String),
            if (terminal.syncError != null)
              const Text('记录暂未同步，已开始的任务可继续。联网后自动重试。'),
            if (terminal.error != null)
              Text(
                terminal.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      );
    },
  );
  void _adjustOpening(
    BuildContext context,
    api.TaskView task,
    api.BatchPlan batch,
  ) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('调整出药开口'),
      content: SizedBox(
        width: 360,
        child: ListenableBuilder(
          listenable: terminal,
          builder: (context, _) => _GateControl(
            terminal: terminal,
            initial:
                (terminal.state['gate'] as num?)?.toDouble() ??
                batch.parameters.gate.toDouble(),
            key: ValueKey('${task.id}-${batch.index}'),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('完成'),
        ),
      ],
    ),
  );
}

class _GateControl extends StatefulWidget {
  const _GateControl({
    super.key,
    required this.terminal,
    required this.initial,
  });
  final TerminalController terminal;
  final double initial;
  @override
  State<_GateControl> createState() => _GateControlState();
}

class _GateControlState extends State<_GateControl> {
  late double value = widget.initial;
  Timer? debounce;
  double? lastSent;
  void send() {
    debounce?.cancel();
    if (!mounted ||
        !['ready', 'running', 'paused'].contains(widget.terminal.phase) ||
        lastSent == value) {
      return;
    }
    if (widget.terminal.busy || widget.terminal.state['pending'] != null) {
      debounce = Timer(const Duration(milliseconds: 100), send);
      return;
    }
    lastSent = value;
    widget.terminal.action('gate', {'value': value});
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('开口刻度 ${value.toStringAsFixed(2)}（数值越小，开口越大）'),
      Slider(
        value: value,
        divisions: 100,
        onChanged: widget.terminal.busy
            ? null
            : (v) {
                setState(() => value = v);
                debounce?.cancel();
                debounce = Timer(const Duration(milliseconds: 400), send);
              },
        onChangeEnd: (_) => send(),
      ),
    ],
  );
}

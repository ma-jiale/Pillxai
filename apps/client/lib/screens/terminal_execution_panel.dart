import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;

import '../data/terminal_controller.dart';
import '../widgets/execution_medicine_card.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/dispenser_icon.dart';
import 'terminal_device_dialog.dart';

class TerminalExecutionPanel extends StatelessWidget {
  const TerminalExecutionPanel({super.key, required this.terminal});
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
              ResidentIdentity(
                name: task.plan.residentName,
                bed: task.plan.bed,
              ),
              const SizedBox(height: 24),
              if (simulator)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('模拟演练'),
                ),
              if (!waiting && batch != null) ...[
                ExecutionMedicineCard(
                  batch: batch,
                  count: terminal.count,
                  stage:
                      '${batch.purpose} · 第 ${batch.index + 1} / ${task.batches.length} 药',
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
                      ? '本次已完成'
                      : '本次已结束',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(terminal.state['message'] as String? ?? ''),
              if (!terminal.ownTask) const Text('当前任务属于其他账号，请使用原账号登录。'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  if (phase == 'ready')
                    FilledButton(
                      onPressed:
                          terminal.busy ||
                              !terminal.recognized ||
                              !terminal.ownTask
                          ? null
                          : terminal.start,
                      child: Text(
                        terminal.state['permitted'] == true ? '已换好，继续' : '开始摆药',
                      ),
                    ),
                  if (phase == 'running')
                    FilledButton(
                      onPressed: terminal.busy
                          ? null
                          : () => terminal.action('pause'),
                      child: const Text('暂停'),
                    ),
                  if (phase == 'paused')
                    FilledButton(
                      onPressed: terminal.busy
                          ? null
                          : () => terminal.action('resume'),
                      child: const Text('继续'),
                    ),
                  if (phase == 'recovery') ...[
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
                              terminal.state['reset_observed'] == true ||
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
                  if (![
                    'awaitingSafeConfirmation',
                    'cancelled',
                    'completed',
                    'deleting',
                  ].contains(phase))
                    TextButton(
                      onPressed:
                          terminal.busy ||
                              !terminal.connected ||
                              terminal.state['pending'] != null
                          ? null
                          : () => terminal.action('stop'),
                      child: const Text('停止并结束本次'),
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
                  OutlinedButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => TerminalDeviceDialog(terminal: terminal),
                    ),
                    child: const Text('查看设备'),
                  ),
                ],
              ),
              if (['ready', 'running', 'paused'].contains(phase) &&
                  batch != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('调整出药开口'),
                    onPressed: !terminal.ownTask
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('调整出药开口'),
                              content: SizedBox(
                                width: 420,
                                child: ListenableBuilder(
                                  listenable: terminal,
                                  builder: (context, _) => _GateControl(
                                    terminal: terminal,
                                    initial:
                                        (terminal.state['gate'] as num?)
                                            ?.toDouble() ??
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
                          ),
                  ),
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

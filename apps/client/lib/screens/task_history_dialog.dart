import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;

import '../data/terminal_controller.dart';

class TaskHistoryDialog extends StatefulWidget {
  const TaskHistoryDialog({super.key, required this.terminal});
  final TerminalController terminal;
  @override
  State<TaskHistoryDialog> createState() => _TaskHistoryDialogState();
}

class _TaskHistoryDialogState extends State<TaskHistoryDialog> {
  late final future = widget.terminal.backend.request(
    widget.terminal.execution.listTasks(active: false),
  );
  static const states = {
    'claimed': '已领取',
    'started': '执行中',
    'awaiting_collection': '摆药完成，待取盒',
    'completed': '已完成',
    'cancelled': '已取消',
  };
  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('执行记录', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<api.TaskView>?>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text(snapshot.error.toString());
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.isEmpty) {
                    return const Center(child: Text('尚无执行记录。'));
                  }
                  return ListView(
                    children: snapshot.data!
                        .map(
                          (task) => ExpansionTile(
                            title: Text(
                              '${task.plan.residentName} · ${states[task.state.toJson()] ?? task.state.toJson()}',
                            ),
                            subtitle: Text(
                              '${task.device.configuration.mode == api.DeviceMode.simulator ? "模拟机 · " : ""}${task.device.configuration.name} · ${task.updatedAt.toLocal()}',
                            ),
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('以下是机器累计计数；不代表逐格实测数量。'),
                              ),
                              for (final batch in task.batches)
                                ListTile(
                                  title: Text(
                                    '${batch.name} · ${batch.purpose}',
                                  ),
                                  subtitle: Text(
                                    '计划 ${batch.total} 颗 · 反馈 ${task.counts[batch.index]} 颗 · ${task.completedBatches.contains(batch.index) ? "收到完成反馈" : "未确认完成"}',
                                  ),
                                ),
                            ],
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    ),
  );
}

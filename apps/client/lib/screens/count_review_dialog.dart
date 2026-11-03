import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;

import '../data/terminal_controller.dart';
import '../models/pillbox_layout.dart';
import 'motor_stall_dialog.dart';

class CountReviewDialog extends StatelessWidget {
  const CountReviewDialog({
    super.key,
    required this.terminal,
    required this.task,
    required this.batch,
  });

  final TerminalController terminal;
  final api.TaskView task;
  final api.BatchPlan batch;
  static bool active(String phase) =>
      phase == 'openingForReview' || phase == 'reviewingCount';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: terminal,
    builder: (context, _) {
      if (!active(terminal.phase) ||
          terminal.task?.id != task.id ||
          terminal.batch?.index != batch.index) {
        final route = ModalRoute.of(context);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (route != null && route.isActive) {
            route.navigator?.removeRoute(route);
          }
        });
        return const SizedBox.shrink();
      }
      final opened = terminal.phase == 'reviewingCount';
      final next = task.batches.elementAtOrNull(batch.index + 1);
      final changeTray = next != null && next.tray != batch.tray;
      final ready =
          terminal.view['can_confirm_count_review'] == true &&
          terminal.ownTask &&
          !terminal.busy;
      final config = task.device.configuration;
      String dayPlan(int day) {
        final column = config.reverseColumns ? 6 - day : day;
        return [
          for (final slot in task.plan.settings.visibleBoxOrder)
            '${task.plan.slots[slot]} ${batch.matrix[config.rows[slot]][column]} 颗',
        ].join('　');
      }

      return PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('当前药物摆药错误，请停止投料'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${task.plan.residentName} · ${batch.purpose}'),
              Text(
                '${batch.name} · ${batch.strength} · ${batch.feedForm == 'half' ? '预切半片' : '整片／整粒'}',
              ),
              Text('机器最后报告 ${terminal.count} 颗，本盘计划 ${batch.total} 颗。'),
              const SizedBox(height: 12),
              Text(terminal.state['message'] as String? ?? ''),
              if (opened) ...[
                for (final (day, date) in task.plan.dates.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('${date.month}月${date.day}日　${dayPlan(day)}'),
                  ),
                if (next != null)
                  Text(
                    changeTray
                        ? '核对后取出本盘，换入「${next.purpose}」，等待识别。'
                        : '核对后请将本盘放回，等待识别。',
                  ),
              ],
              if (terminal.error != null) Text(terminal.error!),
            ],
          ),
          actions: [
            for (final notice
                in (terminal.view['stall_notices'] as List? ?? []).cast<Map>())
              if (notice['seen'] == true)
                TextButton(
                  onPressed: terminal.state['pending'] != null
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => MotorStallDialog(
                            terminal: terminal,
                            notice: Map<String, dynamic>.from(notice),
                          ),
                        ),
                  child: Text('处理 ${notice['motor']} 号电机堵转'),
                ),
            for (final notice
                in (terminal.view['stall_notices'] as List? ?? []).cast<Map>())
              if (notice['seen'] == true)
                TextButton(
                  onPressed: terminal.state['pending'] != null
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => MotorStallDialog(
                            terminal: terminal,
                            notice: Map<String, dynamic>.from(notice),
                          ),
                        ),
                  child: Text('处理 ${notice['motor']} 号电机堵转'),
                ),
            if (opened)
              FilledButton(
                onPressed: ready
                    ? () => terminal.action('confirm_count_review', {
                        'task_id': task.id,
                        'batch': batch.index,
                      })
                    : null,
                child: Text(next == null ? '已核对，结束摆药' : '已核对，继续下一药'),
              ),
          ],
        ),
      );
    },
  );
}

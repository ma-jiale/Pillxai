import 'package:flutter/material.dart';

import '../data/terminal_controller.dart';

/// The executor owns the pause and verifies task/batch identity for every action.
class SkipMedicineDialog extends StatefulWidget {
  const SkipMedicineDialog({
    super.key,
    required this.terminal,
    required this.taskId,
    required this.batch,
    required this.name,
  });
  final TerminalController terminal;
  final String taskId;
  final int batch;
  final String name;

  @override
  State<SkipMedicineDialog> createState() => _SkipMedicineDialogState();
}

class _SkipMedicineDialogState extends State<SkipMedicineDialog> {
  bool manual = false;
  Map<String, dynamic> get identity => {
    'task_id': widget.taskId,
    'batch': widget.batch,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.terminal.phase != 'reviewingSkip') {
        widget.terminal.action('review_skip', identity);
      }
    });
  }

  Future<void> submit({bool cancel = false, bool all = false}) async {
    await widget.terminal.action(cancel ? 'cancel_skip' : 'skip', {
      ...identity,
      if (!cancel) 'all_remaining': all,
      if (!cancel) 'manual': !all && manual,
    });
    if (mounted && widget.terminal.phase != 'reviewingSkip') {
      final route = ModalRoute.of(context);
      if (route != null) {
        // A global disconnect notice may have opened while the command waited.
        // Remove only this dialog, never pop that unacknowledged notice.
        Navigator.of(context).removeRoute(route);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.terminal,
    builder: (context, _) {
      final terminal = widget.terminal;
      final sameBatch =
          terminal.task?.id == widget.taskId &&
          terminal.batch?.index == widget.batch;
      final ready =
          sameBatch &&
          terminal.phase == 'reviewingSkip' &&
          terminal.state['pending'] == null &&
          terminal.connected &&
          !terminal.busy;
      final failed =
          !sameBatch ||
          [
            'recovery',
            'deleting',
            'openingForReview',
            'reviewingCount',
          ].contains(terminal.phase) ||
          (terminal.error != null && terminal.phase != 'reviewingSkip');
      return PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text('跳过${widget.name}'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    failed
                        ? '设备状态已变化，请返回执行页核对。'
                        : ready
                        ? '本次仅处理当前药盘中的这份用药，已有计数会保留。'
                        : '正在等待停转确认，请勿投料。',
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: manual,
                    onChanged: ready
                        ? (value) => setState(() => manual = value!)
                        : null,
                    title: const Text('将此药标记为已摆好'),
                    subtitle: const Text('勾选表示已人工核对本盘该药全部按计划摆齐。'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (terminal.error != null) Text(terminal.error!),
                ],
              ),
            ),
          ),
          actions: [
            if (failed)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回核对'),
              )
            else ...[
              TextButton(
                onPressed: ready ? () => submit(cancel: true) : null,
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: ready ? () => submit() : null,
                child: const Text('确认跳过'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: ready ? () => submit(all: true) : null,
                child: const Text('跳过该长者所有剩余药物'),
              ),
            ],
          ],
        ),
      );
    },
  );
}

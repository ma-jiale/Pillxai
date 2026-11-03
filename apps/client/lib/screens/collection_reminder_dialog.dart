import 'package:flutter/material.dart';

import '../data/terminal_controller.dart';

class CollectionReminderDialog extends StatefulWidget {
  const CollectionReminderDialog({
    super.key,
    required this.terminal,
    required this.taskId,
    required this.name,
    required this.bed,
    required this.hasSkipped,
  });
  final TerminalController terminal;
  final String taskId;
  final String name;
  final String bed;
  final bool hasSkipped;
  @override
  State<CollectionReminderDialog> createState() =>
      _CollectionReminderDialogState();
}

class _CollectionReminderDialogState extends State<CollectionReminderDialog> {
  bool removing = false;
  @override
  void initState() {
    super.initState();
    widget.terminal.addListener(_changed);
    _changed();
  }

  void _changed() {
    final terminal = widget.terminal;
    final removed =
        terminal.state['tray_present'] == false &&
        terminal.state['absent_at'] != null;
    if (!removing &&
        (removed ||
            terminal.task?.id != widget.taskId ||
            terminal.phase == 'deleting' ||
            terminal.view['disconnect_notice'] != null)) {
      removing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route != null) Navigator.of(context).removeRoute(route);
      });
    }
  }

  @override
  void dispose() {
    widget.terminal.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      title: const Text('请及时取走药盒'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.name} · ${widget.bed}'),
          const SizedBox(height: 12),
          Text(
            widget.hasSkipped
                ? '当前长者的摆药任务已结束，部分药物已跳过，请及时取走药盒。'
                : '当前长者的摆药任务已完成，请及时取走药盒。',
          ),
        ],
      ),
    ),
  );
}

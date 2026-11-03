import 'package:flutter/material.dart';

import '../data/terminal_controller.dart';

class MotorStallDialog extends StatefulWidget {
  const MotorStallDialog({
    super.key,
    required this.terminal,
    required this.notice,
  });
  final TerminalController terminal;
  final Map<String, dynamic> notice;
  @override
  State<MotorStallDialog> createState() => _MotorStallDialogState();
}

class _MotorStallDialogState extends State<MotorStallDialog> {
  bool release = true;
  String? error;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.terminal,
    builder: (context, _) {
      final terminal = widget.terminal;
      final motor = widget.notice['motor'];
      final canRelease =
          [2, 3].contains(motor) &&
          terminal.connected &&
          terminal.state['pending'] == null &&
          terminal.ownTask;
      return PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('摆药机电机堵转'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('摆药机的 $motor 号电机堵转，请停止投料并排查。'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('解除堵转'),
                value: release,
                onChanged: terminal.busy
                    ? null
                    : (value) => setState(() => release = value!),
              ),
              if (release && !canRelease)
                Text(
                  ![2, 3].contains(motor)
                      ? '该电机的解除指令尚未确认，可取消勾选后关闭提醒。'
                      : '请等待连接及当前命令处理完成；也可取消勾选后关闭提醒。',
                ),
              if (error != null) Text(error!),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: terminal.busy || (release && !canRelease)
                  ? null
                  : () async {
                      await terminal.action('confirm_stall_notice', {
                        'id': widget.notice['id'],
                        'release': release,
                      });
                      if (!context.mounted) return;
                      if (terminal.error != null) {
                        setState(() => error = terminal.error);
                        return;
                      }
                      final route = ModalRoute.of(context);
                      if (route != null) {
                        Navigator.of(context).removeRoute(route);
                      }
                    },
              child: const Text('确定'),
            ),
          ],
        ),
      );
    },
  );
}

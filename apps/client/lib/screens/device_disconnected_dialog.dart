import 'package:flutter/material.dart';

class DeviceDisconnectedDialog extends StatefulWidget {
  const DeviceDisconnectedDialog({super.key, required this.onAcknowledged});
  final Future<void> Function() onAcknowledged;

  @override
  State<DeviceDisconnectedDialog> createState() =>
      _DeviceDisconnectedDialogState();
}

class _DeviceDisconnectedDialogState extends State<DeviceDisconnectedDialog> {
  bool saving = false;
  String? error;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      title: const Text('摆药机连接已断开'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('摆药机连接已断开，本次任务已终止，进度未保存。请停止投料，重启分药机后重新连接'),
          if (error != null) Text(error!),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  setState(() {
                    saving = true;
                    error = null;
                  });
                  try {
                    await widget.onAcknowledged();
                    if (context.mounted) Navigator.of(context).pop();
                  } catch (_) {
                    if (mounted) {
                      setState(() {
                        saving = false;
                        error = '确认未保存，请重试。';
                      });
                    }
                  }
                },
          child: const Text('我知道了'),
        ),
      ],
    ),
  );
}

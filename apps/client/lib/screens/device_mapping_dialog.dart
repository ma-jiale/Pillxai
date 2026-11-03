import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;

import '../data/terminal_controller.dart';
import '../widgets/app_menu.dart';

class DeviceMappingDialog extends StatefulWidget {
  const DeviceMappingDialog({super.key, required this.terminal});
  final TerminalController terminal;

  @override
  State<DeviceMappingDialog> createState() => _DeviceMappingDialogState();
}

class _DeviceMappingDialogState extends State<DeviceMappingDialog> {
  late final api.DeviceView? original = widget.terminal.device;
  late final rows = List<int>.of(original?.configuration.rows ?? [2, 1, 0, 3]);
  late bool reverse = original?.configuration.reverseColumns ?? false;
  late bool verified = original?.configuration.positionsVerified ?? false;
  bool saved = false;
  static const slots = ['第 1 排', '第 2 排', '第 3 排', '第 4 排'];

  Future<void> save() async {
    final device = original;
    if (device == null) return;
    await widget.terminal.run(() async {
      await widget.terminal.savePositionMapping(
        device,
        rows: rows,
        reverseColumns: reverse,
        verified: verified,
      );
      if (mounted) setState(() => saved = true);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.terminal,
    builder: (context, _) {
      final terminal = widget.terminal;
      final editable =
          original != null &&
          terminal.canMaintain &&
          !terminal.active &&
          !terminal.busy &&
          !saved &&
          terminal.device?.id == original?.id;
      return AlertDialog(
        title: const Text('校准设备行列'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (original == null)
                  const Text('请先在摆药页的“我的设备”中选择并保存设备。')
                else ...[
                  Text(
                    original!.configuration.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('按药盒从上到下的物理排位，核对当前设备对应的协议行号。'),
                  const SizedBox(height: 16),
                  for (var index = 0; index < slots.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppSelect<int>(
                        key: ValueKey('${slots[index]}-${rows[index]}'),
                        value: rows[index],
                        label: '${slots[index]}对应机器行',
                        showLabel: true,
                        enabled: editable,
                        options: [
                          for (var row = 0; row < 4; row++)
                            AppSelectOption(row, '第 $row 行'),
                        ],
                        onChanged: (value) => setState(() {
                          final other = rows.indexOf(value);
                          rows[other] = rows[index];
                          rows[index] = value;
                          verified = false;
                        }),
                      ),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('日期列反向'),
                    subtitle: Text(
                      reverse
                          ? '第 1 天对应机器第 6 列，依次到第 0 列。'
                          : '第 1 天对应机器第 0 列，依次到第 6 列。',
                    ),
                    value: reverse,
                    onChanged: editable
                        ? (value) => setState(() {
                            reverse = value;
                            verified = false;
                          })
                        : null,
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('已在现场核对以上行位置和日期方向'),
                    controlAffinity: ListTileControlAffinity.leading,
                    value: verified,
                    onChanged: editable
                        ? (value) => setState(() => verified = value!)
                        : null,
                  ),
                  const Text('校准结果仅用于当前设备。开始实机摆药前须完成现场核对。'),
                  if (terminal.active) const Text('当前机器有未结束任务，结束后可修改映射。'),
                  if (!terminal.canMaintain)
                    const Text('当前账号仅可查看，请联系有维护权限的人员修改。'),
                  if (saved) const Text('映射已保存'),
                  if (terminal.error != null)
                    Text(
                      terminal.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: terminal.busy ? null : () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          if (original != null)
            FilledButton(
              onPressed: editable ? save : null,
              child: Text(terminal.busy ? '保存中…' : '保存映射'),
            ),
        ],
      );
    },
  );
}

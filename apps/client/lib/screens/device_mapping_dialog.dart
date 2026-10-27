import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;

import '../data/terminal_controller.dart';

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
  static const slots = ['早', '午', '晚', '睡前'];

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
        title: const Text('实体位置映射'),
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
                  const Text('按当前机器的实际位置设置。机器行号为 0–3，四个时段不能重复。'),
                  const SizedBox(height: 16),
                  for (var index = 0; index < slots.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('${slots[index]}-${rows[index]}'),
                        initialValue: rows[index],
                        decoration: InputDecoration(
                          labelText: '${slots[index]}对应机器行',
                        ),
                        items: [
                          for (var row = 0; row < 4; row++)
                            DropdownMenuItem(
                              value: row,
                              child: Text('第 $row 行'),
                            ),
                        ],
                        onChanged: editable
                            ? (value) => setState(() {
                                if (value == null) return;
                                final other = rows.indexOf(value);
                                rows[other] = rows[index];
                                rows[index] = value;
                                verified = false;
                              })
                            : null,
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
                  const Text('保存只更新当前机器的布局，不会驱动电机。未核对的配置可以保存，但不能开始实机摆药。'),
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

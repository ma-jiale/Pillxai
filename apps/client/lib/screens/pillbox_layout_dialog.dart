import 'package:flutter/material.dart';

import '../data/settings_controller.dart';
import '../models/pillbox_layout.dart';
import '../widgets/app_menu.dart';

class PillboxLayoutDialog extends StatefulWidget {
  const PillboxLayoutDialog({super.key, required this.settings});
  final SettingsController settings;

  @override
  State<PillboxLayoutDialog> createState() => _PillboxLayoutDialogState();
}

class _PillboxLayoutDialogState extends State<PillboxLayoutDialog> {
  late final original = widget.settings.saved;
  late final order = [...original.fullBoxOrder];
  String? error;
  bool saving = false;

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.settings.saveSettings(
        days: original.preparationDays,
        split: original.splitMeals,
        night: original.bedtimeEnabled,
        tomorrow: original.startTomorrow,
        boxSlotOrder: order,
        expectedRevision: original.revision,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (failure) {
      if (mounted) {
        setState(() {
          saving = false;
          error = failure.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = order
        .where((slot) => original.bedtimeEnabled || slot != 3)
        .toList();
    final editable = !saving && widget.settings.canSaveRules;
    return AlertDialog(
      title: const Text('药盒格位顺序'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('按药盒从上到下排列。保存后，所有摆药机的新计划使用同一顺序。'),
              for (final (row, slot) in visible.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: AppSelect<int>(
                    label: '第 ${row + 1} 排',
                    showLabel: true,
                    value: slot,
                    enabled: editable,
                    options: [
                      for (final option in original.visibleBoxOrder)
                        AppSelectOption(option, pillboxSlots[option]),
                    ],
                    onChanged: (value) => setState(() {
                      final from = order.indexOf(slot),
                          to = order.indexOf(value);
                      order[from] = value;
                      order[to] = slot;
                    }),
                  ),
                ),
              if (error != null) Text(error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        if (widget.settings.canSaveRules || saving)
          FilledButton(
            onPressed: editable ? save : null,
            child: const Text('保存映射'),
          ),
      ],
    );
  }
}

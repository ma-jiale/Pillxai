import 'package:flutter/material.dart';

import '../widgets/app_menu.dart';
import '../widgets/dispensing_medicine_cards.dart';

import '../models/demo_model.dart';
import '../theme/app_page.dart';

enum _SkipChoice { current, prepared, remaining }

/// 执行状态的投影。只在 model.active 时使用；页面不拥有计时器或任务。
/// 点击暂停等按钮调用模型方法，监听通知后重新描述当前画面。
class DispensingPage extends StatelessWidget {
  const DispensingPage({super.key, required this.model});
  final DemoModel model;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => LayoutBuilder(
      builder: (context, bounds) {
        final compact = bounds.maxWidth < 700;
        return SingleChildScrollView(
          padding: AppPage.insets(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, compact),
              const SizedBox(height: 38),
              DispensingMedicineCards(
                current: _displayMedicine(model.currentMedicine),
                next: model.nextMedicine == null
                    ? null
                    : _displayMedicine(model.nextMedicine!),
                count: model.count,
                stageLabel: model.stageLabel,
                progressLabel: model.stage == DispenseStage.completed
                    ? (model.hasSkippedMedicines ? '本次已结束' : '本次已完成')
                    : '已摆',
              ),

              const SizedBox(height: 24),
              _actions(context),
            ],
          ),
        );
      },
    ),
  );

  Widget _header(BuildContext context, bool compact) => DispensingIdentity(
    name: model.taskResidentName,
    bed: model.taskResidentBed,
    avatar: model.taskResidentAvatar,
    stage: model.stageLabel,
  );

  Widget _actions(BuildContext context) {
    // 执行页仅在 active 时挂载；此处只需表达运行和暂停两个操作。
    final running = model.stage == DispenseStage.running;
    final label = running ? '暂停' : '继续摆药';
    final icon = running ? Icons.pause_rounded : Icons.play_arrow_rounded;
    final action = running ? model.pause : model.resume;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DispensingPrimaryButton(
          label: label,
          icon: icon,
          onPressed: model.active ? action : null,
        ),
        OutlinedButton.icon(
          key: const ValueKey('skip-medicine'),
          onPressed: model.active ? () => _skip(context) : null,
          icon: const Icon(Icons.skip_next_rounded, size: 20),
          label: const Text('跳过'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('adjust-opening'),
          onPressed:
              model.stage == DispenseStage.completed ||
                  model.stage == DispenseStage.cancelled
              ? null
              : () => _adjustOpening(context),
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: const Text('调整开口'),
        ),
        AppActionMenu(
          tooltip: '更多操作',
          actions: [
            AppMenuAction(
              '查看本次计划',
              () => _showPlan(context),
              icon: Icons.list_alt_rounded,
            ),
            if (model.stage != DispenseStage.cancelled &&
                model.stage != DispenseStage.completed)
              AppMenuAction(
                '结束本次摆药',
                () => _cancel(context),
                icon: Icons.stop_circle_outlined,
              ),
          ],
        ),
      ],
    );
  }

  /// 弹窗前暂停并记住任务/药物身份；await 后重新核对，避免操作过期对象。
  /// 取消恢复打开前的运行状态；确认时把人工数量和原计数分别保存。
  Future<void> _skip(BuildContext context) async {
    if (!model.active) return;
    final task = model.taskMedicines;
    final index = model.medicineIndex;
    final medicine = model.currentMedicine;
    final wasRunning = model.stage == DispenseStage.running;
    final remaining = task.length - index;
    final messenger = ScaffoldMessenger.of(context);
    model.pause();
    var markPrepared = false;
    final choice = await showDialog<_SkipChoice>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          scrollable: true,
          title: const Text('跳过当前药物？'),
          content: SizedBox(
            width: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${model.taskResidentName}  ${model.taskResidentBed}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff737373),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  medicine.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${medicine.strength} · 已摆 ${model.count} / ${medicine.target} 颗',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xff737373),
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  key: const ValueKey('skip-mark-prepared'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: markPrepared,
                  onChanged: (value) =>
                      update(() => markPrepared = value ?? false),
                  title: const Text(
                    '将此药标记为已摆好',
                    style: TextStyle(fontSize: 14),
                  ),
                  subtitle: const Text(
                    '勾选表示已人工核对本次用量全部摆齐。',
                    style: TextStyle(fontSize: 12, color: Color(0xff737373)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('skip-resident'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xffb3261e),
              ),
              onPressed: () => Navigator.pop(context, _SkipChoice.remaining),
              child: const Text('跳过所有'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const ValueKey('skip-confirm'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () => Navigator.pop(
                context,
                markPrepared ? _SkipChoice.prepared : _SkipChoice.current,
              ),
              child: Text(markPrepared ? '标记已摆好' : '确认跳过'),
            ),
          ],
        ),
      ),
    );
    // Do not apply a delayed decision to another medicine or a replaced task.
    if (!identical(task, model.taskMedicines) ||
        index != model.medicineIndex ||
        !model.active) {
      return;
    }
    if (choice == null) {
      if (wasRunning) model.resume();
      return;
    }
    if (choice == _SkipChoice.remaining) {
      model.skipRemaining();
    } else {
      model.skipCurrent(
        markPrepared: choice == _SkipChoice.prepared,
        startNext: wasRunning,
      );
    }
    if (model.active) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(switch (choice) {
            _SkipChoice.remaining => '已跳过该长者剩余 $remaining 种药物',
            _SkipChoice.prepared => '已将${medicine.name}标记为已摆好',
            _SkipChoice.current => '已跳过${medicine.name}',
          }),
        ),
      );
  }

  /// 调整会话模型中的开口比例。当前仅演示UI，不表示设备已执行该设置。
  Future<void> _adjustOpening(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => ListenableBuilder(
      listenable: model,
      builder: (context, _) => AlertDialog(
        title: Text(
          '调整开口 · ${model.currentMedicine.name}',
          style: const TextStyle(fontSize: 18),
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '数值越小，开口越大。',
                style: TextStyle(fontSize: 13, color: Color(0xff777777)),
              ),
              const SizedBox(height: 24),
              Text(
                model.opening.toStringAsFixed(2),
                style: const TextStyle(fontSize: 36),
              ),
              Slider(
                value: model.opening,
                min: 0,
                max: 1,
                divisions: 100,
                label: model.opening.toStringAsFixed(2),
                onChanged: model.setOpening,
              ),
            ],
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
  );

  Future<void> _showPlan(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('本次摆药计划'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${model.taskResidentName} · ${model.taskResidentBed}'),
            const SizedBox(height: 18),
            ...model.taskMedicines.map(
              (medicine) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${medicine.name} · ${medicine.form}'),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${medicine.target} 颗'),
                        if (model.medicineResults[medicine.id]
                            case final result?)
                          Text(
                            result.label,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xff737373),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    ),
  );

  /// 结束确认也先暂停；拒绝结束时恢复原状态，确认后保留结果等待取盒。
  Future<void> _cancel(BuildContext context) async {
    final wasRunning = model.stage == DispenseStage.running;
    if (wasRunning) model.pause();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('结束本次摆药？'),
        content: const Text(
          '已完成药物和已有计数会保留。当前药标为待核实，剩余药物标为未执行；结束后返回首页，结果保存在历史记录。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续当前任务'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('结束摆药'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      model.cancel();
    } else if (wasRunning) {
      model.resume();
    }
  }
}

DispensingMedicine _displayMedicine(Medicine medicine) => DispensingMedicine(
  id: medicine.id,
  name: medicine.name,
  form: medicine.form,
  strength: medicine.strength,
  target: medicine.target,
  image: medicine.imageAsset == null ? null : AssetImage(medicine.imageAsset!),
);

class MedicinePhoto extends StatelessWidget {
  const MedicinePhoto({super.key, required this.medicine});
  final Medicine medicine;
  @override
  Widget build(BuildContext context) => MedicineImage(
    name: medicine.name,
    image: medicine.imageAsset == null
        ? null
        : AssetImage(medicine.imageAsset!),
  );
}

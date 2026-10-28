import '../widgets/medicine_pattern.dart';

import 'package:flutter/material.dart';

import '../models/demo_model.dart';
import '../models/preparation_plan.dart';
import 'dispensing_page.dart';
import 'history_page.dart';
import 'results_page.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/preparation_list.dart';
import '../widgets/app_menu.dart';
import '../theme/app_page.dart';
import '../widgets/preparation_confirmation.dart';

/// 摆药入口：空闲时列计划，执行时显示执行台，历史视图由本页局部切换。
/// 阅读主线：planFor → PreparationDialog → startPreparedTask → DispensingPage。
class PreparationPage extends StatefulWidget {
  const PreparationPage({super.key, required this.model});
  final DemoModel model;
  @override
  State<PreparationPage> createState() => _PreparationPageState();
}

class _PreparationPageState extends State<PreparationPage> {
  bool early = false;
  bool history = false;
  DateTime get today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool isEarly(Resident resident) =>
      (widget.model.demoCoverage[resident.id]?.difference(today).inDays ??
          -1) >=
      2;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      if (history) {
        return HistoryPage(
          model: widget.model,
          onClose: () => setState(() => history = false),
        );
      }
      if (widget.model.active) return DispensingPage(model: widget.model);
      // 一次 build 只算一次计划。校验失败的需求仍在清单中显示原因。
      final plans = widget.model.residents
          .map((resident) => widget.model.planFor(resident, now: today))
          .where((plan) => plan.hasDemand)
          .toList();
      final visible = plans.where((p) => isEarly(p.resident) == early).toList();
      return Padding(
        padding: AppPage.insets(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final value in [false, true])
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xff232323),
                      backgroundColor: early == value
                          ? const Color(0xffefeff1)
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => setState(() => early = value),
                    child: Text(
                      '${value ? '提前准备' : '待准备'} ${plans.where((p) => isEarly(p.resident) == value).length}',
                    ),
                  ),
                TextButton.icon(
                  key: const ValueKey('open-history'),
                  onPressed: () => setState(() => history = true),
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('历史记录'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.model.awaitingCollection) ...[
              CollectionStatusBanner(model: widget.model),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('暂无需要准备的长者'))
                  : PreparationList(
                      entries: [
                        for (final plan in visible)
                          PreparationListEntry(
                            name: plan.resident.name,
                            bed: plan.resident.bed,
                            avatar: plan.resident.avatarAsset,
                            hasIssue: plan.issue != null,
                            details:
                                plan.issue ??
                                '${early ? '可提前准备下一周期' : '待准备'}\n${plan.medicines.length} 种药 · ${plan.dates}',
                            action: OutlinedButton(
                              key: ValueKey('prepare-${plan.resident.id}'),
                              onPressed: () => showDialog<void>(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => PreparationDialog(
                                  model: widget.model,
                                  resident: plan.resident,
                                  start: plan.start,
                                ),
                              ),
                              child: const Text('开始摆药'),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      );
    },
  );
}

/// 确认窗口拥有“本次天数”和未开始计划，反馈由共享模型提供。
/// 关闭图案不会销毁此窗口，因此天数保留；收到新反馈则重新判断启动条件。
class PreparationDialog extends StatefulWidget {
  const PreparationDialog({
    super.key,
    required this.model,
    required this.resident,
    required this.start,
  });
  final DemoModel model;
  final Resident resident;
  final DateTime start;
  @override
  State<PreparationDialog> createState() => _PreparationDialogState();
}

class _PreparationDialogState extends State<PreparationDialog> {
  int days = 7;
  bool get opening => widget.model.boxFeedback.value == BoxFeedback.opening;
  BoxFeedback get feedback => widget.model.boxFeedback.value;
  late PreparationPlan plan;
  @override
  void initState() {
    super.initState();
    rebuildPlan();
    // 预览没有真实适配器，不能复用上次匹配当作本次已识别。测试从窗口外注入反馈。
    widget.model.boxFeedback.value = BoxFeedback.disconnected;
  }

  /// 天数变化时创建新计划，不修改处方或已开始任务。起日固定为打开窗口时的日期。
  void rebuildPlan() {
    plan = PreparationPlan(
      widget.resident,
      widget.start,
      days,
      bedtime: widget.model.bedtime,
    );
  }

  bool get matched => feedback == BoxFeedback.match;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<BoxFeedback>(
    valueListenable: widget.model.boxFeedback,
    builder: (context, _, _) => PreparationConfirmation(
      children: [
        const Text(
          '确认摆药信息',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        ResidentIdentity(
          name: widget.resident.name,
          bed: widget.resident.bed,
          asset: widget.resident.avatarAsset,
          size: 44,
          nameSize: 18,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 20,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('覆盖日期  ${plan.dates}'),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('本次天数  '),
                SizedBox(
                  width: 94,
                  child: AppSelect<int>(
                    key: const ValueKey('preparation-days'),
                    value: days,
                    label: '本次天数',
                    options: [
                      for (var i = 1; i <= 7; i++) AppSelectOption(i, '$i 天'),
                    ],
                    onChanged: (value) => setState(() {
                      days = value;
                      rebuildPlan();
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
        const Divider(),
        Row(
          children: [
            Expanded(child: Text('本次用药 · ${plan.medicines.length} 种')),
            const SizedBox(width: 12),
            FilledButton.icon(
              key: const ValueKey('pattern-open'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => PatternDialog(plan: plan),
              ),
              icon: const Icon(Icons.grid_on_rounded, size: 18),
              label: const Text('预览摆药图案'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Flexible(
          child: PreparationMedicineTable(
            slots: ['早', '午', '晚', if (widget.model.bedtime) '睡前'],
            rows: [
              for (final medicine in plan.medicines)
                PreparationMedicineRow(
                  name: medicine.name,
                  description: '${medicine.strength} · ${medicine.form}',
                  doses: [
                    for (final dose in medicine.doses.values.take(
                      widget.model.bedtime ? 4 : 3,
                    ))
                      dose == 0 ? '—' : formatDose(dose),
                  ],
                  total: '${medicine.target}颗',
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (plan.issue != null)
          Text(
            plan.issue!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xfff5f5f5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                opening
                    ? '正在开仓…'
                    : switch (feedback) {
                        BoxFeedback.match => '药盒匹配，已确认 ${widget.resident.name}',
                        BoxFeedback.other => '请更换为${widget.resident.name}的药盒',
                        BoxFeedback.failed => '开仓失败，请检查设备连接',
                        BoxFeedback.disconnected => '摆药机未连接，请先连接设备',
                        BoxFeedback.opening => '正在开仓…',
                        BoxFeedback.waiting => '请放入${widget.resident.name}的药盒',
                      },
                style: TextStyle(
                  color: feedback == BoxFeedback.other
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            const SizedBox(width: 12),
            FilledButton(
              key: const ValueKey('confirm-dispense'),
              onPressed: matched && plan.canStart
                  ? () {
                      if (widget.model.startPreparedTask(plan)) {
                        Navigator.pop(context);
                      }
                    }
                  : null,
              child: const Text('开始摆药'),
            ),
          ],
        ),
      ],
    ),
  );
}

/// 只读计划图。highlighted/detail 是展示状态，不参与任务、计数和覆盖。
/// 点按药格显示精确文字数量；颜色只作为辅助识别。
class PatternDialog extends StatelessWidget {
  const PatternDialog({super.key, required this.plan});
  final PreparationPlan plan;
  @override
  Widget build(BuildContext context) => MedicinePatternDialog(
    plan: MedicinePatternPlan(
      residentName: plan.resident.name,
      start: plan.start,
      days: plan.days,
      dates: plan.dates,
      slots: ['早', '午', '晚', if (plan.bedtime) '睡前'],
      medicines: [
        for (final medicine in plan.medicines)
          MedicinePatternItem(
            name: medicine.name,
            strength: medicine.strength,
            form: medicine.form,
            target: medicine.target,
            particles: [
              for (var day = 0; day < plan.days; day++)
                [
                  for (var slot = 0; slot < (plan.bedtime ? 4 : 3); slot++)
                    PreparationPlan.particles(
                      medicine,
                      slot,
                      DateTime(
                        plan.start.year,
                        plan.start.month,
                        plan.start.day + day,
                      ),
                    ),
                ],
            ],
          ),
      ],
    ),
  );
}

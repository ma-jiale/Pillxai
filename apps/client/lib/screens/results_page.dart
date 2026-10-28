import '../widgets/result_details.dart';
export '../widgets/result_details.dart' show ResultBadge;

import 'package:flutter/material.dart';

import '../models/demo_model.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/collection_banner.dart';

/// 用稳定id查询当前快照；监听模型是为了同步取盒反馈，不是允许编辑历史。
/// 返回的Future在详情关闭时完成，调用页可据此恢复自己的导航状态。
Future<void> showResultDetails(
  BuildContext context,
  DemoModel model,
  String id,
) => showDialog<void>(
  context: context,
  builder: (_) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final record = model.records.where((r) => r.id == id).firstOrNull;
      if (record == null) return const SizedBox.shrink();
      return ResultDetailsSheet(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RecordSummary(record: record),
            const SizedBox(height: 28),
            const Text(
              '逐药结果',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              '计数为演练累计值，不能代表每个药格的实际数量。',
              style: TextStyle(fontSize: 12, color: Color(0xff777777)),
            ),
            const SizedBox(height: 12),
            for (final medicine in record.medicines)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            medicine.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          ResultBadge(
                            medicine.result.label,
                            attention:
                                medicine.result.outcome ==
                                    MedicineOutcome.skipped ||
                                medicine.result.outcome ==
                                    MedicineOutcome.unverified ||
                                medicine.result.outcome ==
                                    MedicineOutcome.notStarted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${medicine.strength} · ${medicine.form}',
                        style: const TextStyle(color: Color(0xff777777)),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 24,
                        runSpacing: 8,
                        children: [
                          Text('计划 ${medicine.target} 颗'),
                          Text('演练计数 ${medicine.result.countedParticles} 颗'),
                          if (medicine.result.confirmedParticles != null)
                            Text(
                              '人工确认 ${medicine.result.confirmedParticles} 颗',
                            ),
                        ],
                      ),
                      if (medicine.result.outcome == MedicineOutcome.unverified)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            '已结束，实际摆药数量仍待核实。',
                            style: TextStyle(color: Color(0xff9a6324)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('原计划', style: TextStyle(fontSize: 14)),
              children: [
                for (final medicine in record.medicines)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(medicine.name),
                    subtitle: Text('${medicine.schedule} · ${medicine.form}'),
                  ),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: record.needsReview,
              title: const Text('处理经过', style: TextStyle(fontSize: 14)),
              children: [
                for (final event in record.events)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      event.description,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      recordTime(event.at),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ],
        ),
        footer:
            record.isExample &&
                record.collection != CollectionStage.complete &&
                !model.busy
            ? FilledButton.icon(
                key: const ValueKey('preview-collection'),
                onPressed: () {
                  if (model.openExampleCollection(record.id)) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.output_rounded, size: 18),
                label: const Text('演示自动取盒反馈'),
              )
            : null,
      );
    },
  ),
);

/// 展示任务发生时的资料快照，不能改读当前长者资料来“更新”历史。
class RecordSummary extends StatelessWidget {
  const RecordSummary({super.key, required this.record});
  final DispenseRecord record;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ResidentIdentity(
        name: record.name,
        bed: record.bed,
        asset: record.avatar,
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ResultBadge(
            record.label,
            attention: record.outcome != TaskOutcome.completed,
          ),
          if (record.needsReview) const ResultBadge('有待核实药物', attention: true),
          ResultBadge(record.collectionLabel),
          const ResultBadge('演练'),
        ],
      ),
      const SizedBox(height: 14),
      Text('${record.completedCount} / ${record.medicines.length} 种药已完成或人工确认'),
      const SizedBox(height: 8),
      Text(
        '摆药时间  ${recordTime(record.finishedAt)}',
        style: const TextStyle(color: Color(0xff777777), fontSize: 12),
      ),
      if (record.coverageStart != null && record.coverageEnd != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '计划日期  ${recordDate(record.coverageStart!)} — ${recordDate(record.coverageEnd!)}',
            style: const TextStyle(color: Color(0xff777777), fontSize: 12),
          ),
        ),
      const SizedBox(height: 6),
      Text(
        '${record.device} · ${record.operatorName}',
        style: const TextStyle(color: Color(0xff777777), fontSize: 12),
      ),
      const SizedBox(height: 12),
      Text(
        record.outcome == TaskOutcome.completed
            ? '结果仅保存在本次会话，刷新后清空。'
            : '本次未计为完整覆盖；原计数与处理结果已保留在本次会话。',
        style: const TextStyle(fontSize: 12, color: Color(0xff777777)),
      ),
    ],
  );
}

/// Non-blocking status on the home screen. Collection is driven by feedback.
/// 首页持续展示取盒占用。消失由模型确认离轨和就绪驱动，不使用页面倒计时。
class CollectionStatusBanner extends StatelessWidget {
  const CollectionStatusBanner({super.key, required this.model});
  final DemoModel model;

  @override
  Widget build(BuildContext context) {
    final record = model.currentRecord!;
    final message = switch (record.collection) {
      CollectionStage.waiting => '请取出药盒，等待设备反馈',
      CollectionStage.detectionFailed => '药盒状态暂不可用，等待设备恢复',
      CollectionStage.retracting => '药盒已离轨，等待轨道就绪',
      CollectionStage.retractionFailed => '轨道尚未就绪，等待设备反馈',
      CollectionStage.complete => '取盒已结束',
    };
    return CollectionBanner(
      title: '${record.name} · ${record.label}',
      message: '$message · 演练',
      action: TextButton(
        key: const ValueKey('result-details'),
        onPressed: () => showResultDetails(context, model, record.id),
        child: const Text('结果详情'),
      ),
    );
  }
}

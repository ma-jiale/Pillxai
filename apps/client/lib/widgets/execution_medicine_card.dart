import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;

import 'medicine_card_deck.dart';

/// The immutable task snapshot supplies identity and dose; live state supplies count.
class ExecutionMedicineCard extends StatelessWidget {
  const ExecutionMedicineCard({
    super.key,
    required this.batch,
    required this.count,
    required this.stage,
    this.next,
  });
  final api.BatchPlan batch;
  final api.BatchPlan? next;
  final int count;
  final String stage;

  Widget photo({bool small = false}) => Container(
    height: small ? 130 : 240,
    decoration: BoxDecoration(
      color: const Color(0xfff6f6f6),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.medication_outlined, size: 44, color: Color(0xffaaaaaa)),
          SizedBox(height: 12),
          Text(
            '尚未添加药品图片',
            style: TextStyle(fontSize: 12, color: Color(0xff777777)),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final information = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '当前药物',
          style: TextStyle(fontSize: 12, color: Color(0xff777777)),
        ),
        const SizedBox(height: 12),
        Text(
          batch.name,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          '${batch.strength} · ${batch.feedForm == 'half' ? '人工预切半片' : '整片／整粒'}',
          style: const TextStyle(color: Color(0xff777777)),
        ),
        const SizedBox(height: 32),
        Semantics(
          label: '已摆 $count / ${batch.total} 颗',
          child: ExcludeSemantics(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$count',
                    style: const TextStyle(
                      fontSize: 42,
                      color: Color(0xff222222),
                    ),
                  ),
                  TextSpan(
                    text: ' / ${batch.total}',
                    style: const TextStyle(
                      fontSize: 30,
                      color: Color(0xff999999),
                    ),
                  ),
                  const TextSpan(text: ' 颗', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: batch.total == 0 ? 0 : (count / batch.total).clamp(0, 1),
          minHeight: 6,
          borderRadius: BorderRadius.circular(100),
        ),
        const SizedBox(height: 14),
        Text(
          stage,
          style: const TextStyle(fontSize: 12, color: Color(0xff777777)),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, bounds) => MedicineCardDeck(
        medicineId: '${batch.index}-${batch.prescriptionId}',
        nextMedicineId: next == null
            ? null
            : '${next!.index}-${next!.prescriptionId}',
        stacked: bounds.maxWidth < 900,
        current: LayoutBuilder(
          builder: (context, card) => card.maxWidth < 520
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [photo(), const SizedBox(height: 24), information],
                )
              : Row(
                  children: [
                    Expanded(child: photo()),
                    const SizedBox(width: 32),
                    Expanded(child: information),
                  ],
                ),
        ),
        next: next == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '下一药',
                    style: TextStyle(fontSize: 12, color: Color(0xff777777)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    next!.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${next!.strength} · ${next!.feedForm == 'half' ? '人工预切半片' : '整片／整粒'}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${next!.total} 颗 · ${next!.purpose}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
      ),
    );
  }
}

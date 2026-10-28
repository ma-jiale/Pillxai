import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;

import 'dispensing_medicine_cards.dart';

/// Adapts immutable server batches to the shared presentation, without a demo model.
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

  DispensingMedicine display(api.BatchPlan value) => DispensingMedicine(
    id: '${value.index}-${value.prescriptionId}',
    name: value.name,
    form: value.feedForm == 'half' ? '人工预切半片' : '整片／整粒',
    strength: value.strength,
    target: value.total,
  );

  @override
  Widget build(BuildContext context) => DispensingMedicineCards(
    current: display(batch),
    next: next == null ? null : display(next!),
    count: count,
    stageLabel: stage,
  );
}

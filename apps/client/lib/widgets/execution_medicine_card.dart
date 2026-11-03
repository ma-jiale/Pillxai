import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;

import '../data/medicine_image.dart';

import 'dispensing_medicine_cards.dart';

/// Adapts immutable server batches to the shared presentation, without a demo model.
class ExecutionMedicineCard extends StatefulWidget {
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

  @override
  State<ExecutionMedicineCard> createState() => _ExecutionMedicineCardState();
}

class _ExecutionMedicineCardState extends State<ExecutionMedicineCard> {
  ImageProvider? currentImage;
  ImageProvider? nextImage;
  @override
  void initState() {
    super.initState();
    currentImage = medicineImageProvider(widget.batch.image);
    nextImage = medicineImageProvider(widget.next?.image);
  }

  @override
  void didUpdateWidget(ExecutionMedicineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.batch.image != widget.batch.image) {
      currentImage = medicineImageProvider(widget.batch.image);
    }
    if (oldWidget.next?.image != widget.next?.image) {
      nextImage = medicineImageProvider(widget.next?.image);
    }
  }

  DispensingMedicine display(api.BatchPlan value, ImageProvider? image) =>
      DispensingMedicine(
        id: '${value.index}-${value.prescriptionId}',
        name: value.name,
        form: value.feedForm == 'half' ? '人工预切半片' : '整片／整粒',
        strength: value.strength,
        target: value.total,
        image: image,
      );

  @override
  Widget build(BuildContext context) => DispensingMedicineCards(
    current: display(widget.batch, currentImage),
    next: widget.next == null ? null : display(widget.next!, nextImage),
    count: widget.count,
    stageLabel: widget.stage,
  );
}

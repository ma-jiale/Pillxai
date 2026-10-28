import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;

import 'app_menu.dart';
import 'medicine_pattern.dart';

/// Adapts immutable server counts; does not recompute doses.
class ServerPlanPattern extends StatefulWidget {
  const ServerPlanPattern({super.key, required this.snapshot});
  final api.PlanSnapshot snapshot;
  @override
  State<ServerPlanPattern> createState() => _ServerPlanPatternState();
}

class _ServerPlanPatternState extends State<ServerPlanPattern> {
  int trayIndex = 0;
  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final tray = snapshot.trays[trayIndex];
    return MedicinePatternDialog(
      key: ValueKey(trayIndex),
      traySelector: snapshot.trays.length < 2
          ? null
          : SizedBox(
              width: 200,
              child: AppSelect<int>(
                value: trayIndex,
                label: '药盘',
                options: [
                  for (var i = 0; i < snapshot.trays.length; i++)
                    AppSelectOption(i, snapshot.trays[i].purpose),
                ],
                onChanged: (value) => setState(() => trayIndex = value),
              ),
            ),
      plan: MedicinePatternPlan(
        residentName: snapshot.residentName,
        start: snapshot.dates.first,
        days: snapshot.dates.length,
        dates:
            '${snapshot.dates.first.year}/${snapshot.dates.first.month}/${snapshot.dates.first.day} — ${snapshot.dates.last.year}/${snapshot.dates.last.month}/${snapshot.dates.last.day}',
        slots: snapshot.slots,
        medicines: [
          for (final medicine in tray.medicines)
            MedicinePatternItem(
              name: medicine.prescription.data.medicineName,
              strength: medicine.prescription.data.strength,
              form: medicine.prescription.data.feedForm == api.FeedForm.half
                  ? '人工预切半片'
                  : '整片／整粒',
              target: medicine.totalParticles,
              particles: medicine.particles,
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;

/// Renders server-provided particle counts verbatim; never computes prescription doses.
class ServerPlanPattern extends StatefulWidget {
  const ServerPlanPattern({super.key, required this.snapshot});
  final api.PlanSnapshot snapshot;
  @override
  State<ServerPlanPattern> createState() => _ServerPlanPatternState();
}

class _ServerPlanPatternState extends State<ServerPlanPattern> {
  static const colors = [
    Color(0xff82b4e7),
    Color(0xffe6ae70),
    Color(0xff79b49a),
    Color(0xffbf7591),
    Color(0xff9681bf),
    Color(0xff50b4b1),
    Color(0xffa6805d),
  ];
  int trayIndex = 0;
  int? highlighted;
  String? detail;
  Color color(int i) => colors[i % colors.length];
  String date(DateTime day) => '${day.month}/${day.day}';

  Widget dot(int i) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color(i)
          .withValues(alpha: highlighted == null || highlighted == i ? 1 : .15),
    ),
  );

  double rowHeight(int slot, List<api.PlanMedicine> medicines) {
    var height = 92.0;
    for (var day = 0; day < widget.snapshot.dates.length; day++) {
      final count = medicines.fold(
        0,
        (sum, item) => sum + item.particles[day][slot],
      );
      if (count <= 24) {
        final needed = ((count / 3).ceil() * 15 + 16).toDouble();
        if (needed > height) height = needed;
      }
    }
    return height;
  }

  Widget cell(int day, int slot, List<api.PlanMedicine> medicines) {
    final counts = [for (final item in medicines) item.particles[day][slot]];
    final total = counts.fold(0, (a, b) => a + b);
    return Padding(
      padding: const EdgeInsets.all(3),
      child: InkWell(
        onTap: () => setState(
          () => detail =
              '${date(widget.snapshot.dates[day])} '
              '${widget.snapshot.slots[slot]}：${[for (var i = 0; i < medicines.length; i++)
                if (counts[i] > 0) '${medicines[i].prescription.data.medicineName} ${counts[i]}颗'].join('，')}',
        ),
        child: Container(
          height: rowHeight(slot, medicines),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xffe5e5e5)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: total > 24
              ? Text('$total颗\n点击查看', textAlign: TextAlign.center)
              : Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < counts.length; i++)
                      for (var n = 0; n < counts[i]; n++) dot(i),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final tray = snapshot.trays[trayIndex];
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 740),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('摆药图案', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 8),
              Text(
                '${snapshot.residentName} · ${date(snapshot.dates.first)} — ${date(snapshot.dates.last)}',
              ),
              const SizedBox(height: 12),
              if (snapshot.trays.length > 1)
                Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < snapshot.trays.length; i++)
                      ChoiceChip(
                        label: Text(snapshot.trays[i].purpose),
                        selected: trayIndex == i,
                        onSelected: (_) => setState(() {
                          trayIndex = i;
                          highlighted = null;
                          detail = null;
                        }),
                      ),
                  ],
                )
              else
                Text(tray.purpose),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 38,
                            child: Column(
                              children: [
                                const SizedBox(height: 36),
                                for (
                                  var slot = 0;
                                  slot < snapshot.slots.length;
                                  slot++
                                )
                                  SizedBox(
                                    height: rowHeight(slot, tray.medicines) + 6,
                                    child: Center(
                                      child: Text(snapshot.slots[slot]),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: snapshot.dates.length * 78.0,
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 36,
                                      child: Row(
                                        children: [
                                          for (final day in snapshot.dates)
                                            SizedBox(
                                              width: 78,
                                              child: Text(
                                                date(day),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    for (
                                      var slot = 0;
                                      slot < snapshot.slots.length;
                                      slot++
                                    )
                                      Row(
                                        children: [
                                          for (
                                            var day = 0;
                                            day < snapshot.dates.length;
                                            day++
                                          )
                                            SizedBox(
                                              width: 78,
                                              child: cell(
                                                day,
                                                slot,
                                                tray.medicines,
                                              ),
                                            ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      for (var i = 0; i < tray.medicines.length; i++)
                        TextButton(
                          onPressed: () => setState(
                            () => highlighted = highlighted == i ? null : i,
                          ),
                          child: Row(
                            children: [
                              dot(i),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${tray.medicines[i].prescription.data.medicineName} · '
                                  '${tray.medicines[i].prescription.data.strength} · '
                                  '${tray.medicines[i].prescription.data.feedForm == api.FeedForm.half ? "预切半片" : "整片／整粒"} · '
                                  '${tray.medicines[i].totalParticles}颗',
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (detail != null)
                Text(detail!, style: const TextStyle(fontSize: 12)),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

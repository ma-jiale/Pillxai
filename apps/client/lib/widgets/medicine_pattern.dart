import 'package:flutter/material.dart';

class MedicinePatternItem {
  const MedicinePatternItem({
    required this.name,
    required this.strength,
    required this.form,
    required this.target,
    required this.particles,
  });
  final String name;
  final String strength;
  final String form;
  final int target;
  final List<List<int>> particles;
}

/// Counts are provided by the plan owner. This renderer never calculates doses.
class MedicinePatternPlan {
  const MedicinePatternPlan({
    required this.residentName,
    required this.start,
    required this.days,
    required this.dates,
    required this.slots,
    required this.medicines,
  });
  final String residentName;
  final DateTime start;
  final int days;
  final String dates;
  final List<String> slots;
  final List<MedicinePatternItem> medicines;
  static String date(DateTime day) => '${day.month}/${day.day}';
}

class MedicinePatternDialog extends StatefulWidget {
  const MedicinePatternDialog({
    super.key,
    required this.plan,
    this.traySelector,
  });
  final Widget? traySelector;
  final MedicinePatternPlan plan;
  @override
  State<MedicinePatternDialog> createState() => _MedicinePatternDialogState();
}

class _MedicinePatternDialogState extends State<MedicinePatternDialog> {
  // 这是显示预算，不是药盒容量。超过预算显示精确数量，绝不截断计划。
  static const maxDotsPerCell = 24;
  int? highlighted;
  String? detail;
  static const colors = [
    Color(0xff82b4e7),
    Color(0xffe6ae70),
    Color(0xff79b49a),
    Color(0xffbf7591),
    Color(0xff9681bf),
    Color(0xff50b4b1),
    Color(0xffa6805d),
    Color(0xffc8bd51),
    Color(0xff758399),
  ];
  Color color(int index) => colors[index % colors.length];
  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    final metadataStyle = DefaultTextStyle.of(context).style
        .merge(const TextStyle(color: Colors.grey, fontSize: 12));
    final separator = TextPainter(
      text: TextSpan(text: ' · ', style: metadataStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final separatorWidth = separator.width;
    separator.dispose();
    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < p.medicines.length; i++)
          TextButton(
            onPressed: () =>
                setState(() => highlighted = highlighted == i ? null : i),
            style: TextButton.styleFrom(
              backgroundColor: highlighted == i
                  ? const Color(0xffeeeeee)
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5, right: 8),
                  child: dot(i),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.medicines[i].name),
                      Text(
                        '${p.medicines[i].strength} · ${p.medicines[i].form}\n${p.medicines[i].target}颗',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    final grid = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 560,
        child: Table(
          columnWidths: const {0: FixedColumnWidth(34)},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: [
                const SizedBox(),
                for (var day = 0; day < 7; day++)
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      day < p.days
                          ? MedicinePatternPlan.date(
                              DateTime(
                                p.start.year,
                                p.start.month,
                                p.start.day + day,
                              ),
                            )
                          : '—',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            for (var slot = 0; slot < (p.slots.length); slot++)
              TableRow(
                children: [
                  Text(p.slots[slot]),
                  for (var day = 0; day < 7; day++) cell(day, slot),
                ],
              ),
          ],
        ),
      ),
    );
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
              const SizedBox(height: 6),
              Text.rich(
                key: const ValueKey('pattern-metadata'),
                TextSpan(
                  children: [
                    TextSpan(text: p.residentName),
                    WidgetSpan(child: SizedBox(width: separatorWidth)),
                    TextSpan(text: p.dates),
                  ],
                ),
                style: metadataStyle,
              ),
              if (widget.traySelector != null) ...[
                const SizedBox(height: 12),
                widget.traySelector!,
              ],
              const SizedBox(height: 18),
              Flexible(
                child: LayoutBuilder(
                  builder: (context, bounds) => SingleChildScrollView(
                    child: bounds.maxWidth > 740
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: grid),
                              const SizedBox(width: 16),
                              SizedBox(width: 220, child: legend),
                            ],
                          )
                        : Column(
                            children: [
                              grid,
                              const SizedBox(height: 16),
                              legend,
                            ],
                          ),
                  ),
                ),
              ),
              if (detail != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(detail!, style: const TextStyle(fontSize: 12)),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Spacer(),
                  FilledButton(
                    key: const ValueKey('pattern-close'),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget dot(int index) => Container(
    width: 15,
    height: 15,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color(index).withValues(
        alpha: highlighted == null || highlighted == index ? 1 : .15,
      ),
    ),
  );

  /// 渲染一个日期/时段。圆点数量受显示预算限制，计划总数始终原样保留。
  Widget cell(int day, int slot) {
    final p = widget.plan;
    final date = DateTime(p.start.year, p.start.month, p.start.day + day);
    final counts = [
      for (final m in p.medicines) day < p.days ? m.particles[day][slot] : 0,
    ];
    final total = counts.fold(0, (sum, count) => sum + count);
    return Padding(
      padding: const EdgeInsets.all(3),
      child: InkWell(
        onTap: day >= p.days
            ? null
            : () => setState(
                () => detail =
                    '${MedicinePatternPlan.date(date)} ${p.slots[slot]}：${[for (var i = 0; i < counts.length; i++)
                      if (counts[i] > 0) '${p.medicines[i].name} ${counts[i]}颗'].join('，')}',
              ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: day < p.days ? Colors.white : const Color(0xfff0f0f0),
            border: Border.all(color: const Color(0xffe5e5e5)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: total > maxDotsPerCell
              ? Text(
                  '$total颗\n点击查看',
                  key: ValueKey('pattern-count-$day-$slot'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                )
              : Wrap(
                  spacing: 4,
                  runSpacing: 5,
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
}

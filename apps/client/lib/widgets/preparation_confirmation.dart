import 'package:flutter/material.dart';

/// Approved dialog frame: identity, plan, scrolling medicines and fixed actions.
class PreparationConfirmation extends StatelessWidget {
  const PreparationConfirmation({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

class PreparationMedicineRow {
  const PreparationMedicineRow({
    required this.name,
    required this.description,
    required this.doses,
    required this.total,
    this.details,
  });
  final String name;
  final String description;
  final List<String> doses;
  final String total;
  final String? details;
}

/// Prescribed doses and server-computed totals are inputs, never recalculated here.
class PreparationMedicineTable extends StatefulWidget {
  const PreparationMedicineTable({
    super.key,
    required this.rows,
    required this.slots,
  });
  final List<PreparationMedicineRow> rows;
  final List<String> slots;
  @override
  State<PreparationMedicineTable> createState() =>
      _PreparationMedicineTableState();
}

class _PreparationMedicineTableState extends State<PreparationMedicineTable> {
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Widget row(List<Widget> cells) => LayoutBuilder(
    builder: (context, bounds) => Row(
      children: [
        Expanded(child: cells.first),
        for (var i = 1; i < cells.length; i++)
          SizedBox(
            width: bounds.maxWidth < 440 ? 36 : 48,
            child: Align(
              alignment: i == cells.length - 1
                  ? Alignment.centerRight
                  : Alignment.center,
              child: cells[i],
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 12, color: Color(0xff737373)),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 8),
          child: row([
            const Text('药物'),
            for (final slot in widget.slots) Text(slot),
            const Text('合计'),
          ]),
        ),
      ),
      Flexible(
        child: Scrollbar(
          controller: scroll,
          thumbVisibility: true,
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.only(right: 8),
            key: const ValueKey('confirmation-medicines'),
            children: [
              for (final medicine in widget.rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: row([
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(medicine.name),
                        Text(
                          medicine.description,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        if (medicine.details != null)
                          Text(
                            medicine.details!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                    for (final dose in medicine.doses) Text(dose),
                    Text(medicine.total),
                  ]),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

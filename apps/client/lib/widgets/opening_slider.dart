import 'package:flutter/material.dart';

class OpeningSlider extends StatelessWidget {
  const OpeningSlider({
    super.key,
    required this.gate,
    required this.onChanged,
    this.onChangeEnd,
  });

  final double gate;
  final ValueChanged<double>? onChanged;
  final VoidCallback? onChangeEnd;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Text('小'),
      Expanded(
        child: Slider(
          value: 1 - gate,
          divisions: 100,
          onChanged: onChanged == null
              ? null
              : (opening) => onChanged!((100 - (opening * 100).round()) / 100),
          onChangeEnd: onChangeEnd == null ? null : (_) => onChangeEnd!(),
        ),
      ),
      const Text('大'),
    ],
  );
}

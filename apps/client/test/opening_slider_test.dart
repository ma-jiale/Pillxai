import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillxai_client/widgets/opening_slider.dart';

void main() {
  testWidgets('slider opens to the right without exposing device values', (
    tester,
  ) async {
    final changes = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OpeningSlider(gate: 0.27, onChanged: changes.add)),
      ),
    );
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, closeTo(0.73, 1e-9));
    expect(slider.label, isNull);
    expect(find.text('0.27'), findsNothing);
    expect(changes, isEmpty);
    for (final position in [0.0, 0.73, 1.0]) {
      slider.onChanged!(position);
    }
    expect(changes, [1.0, 0.27, 0.0]);
  });
}

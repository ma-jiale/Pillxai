import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillxai_client/widgets/dispenser_icon.dart';

// Run from apps/client with flutter test tool/export_app_icons.dart.
void main() {
  testWidgets('Export the dispenser outline for platform launchers', (
    tester,
  ) async {
    await tester.pumpWidget(const DispenserIcon(color: Colors.black));
    final painter = tester
        .widget<CustomPaint>(find.byType(CustomPaint))
        .painter!;
    await tester.runAsync(() async {
      Future<Uint8List> render(int size, {bool maskable = false}) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..scale(size / 32);
        final base = Paint()..color = Colors.white;
        if (maskable) {
          canvas.drawRect(const Rect.fromLTWH(0, 0, 32, 32), base);
        } else {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(0.5, 0.5, 31, 31),
              const Radius.circular(6),
            ),
            base,
          );
        }
        final inset = maskable ? 5.5 : 2.0;
        canvas.translate(inset, inset);
        painter.paint(canvas, Size.square(32 - 2 * inset));
        final picture = recorder.endRecording();
        final image = await picture.toImage(size, size);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        picture.dispose();
        return bytes!.buffer.asUint8List();
      }

      for (final entry in {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      }.entries) {
        await File(
          'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
        ).writeAsBytes(await render(entry.value));
      }
      for (final size in [192, 512]) {
        await File('web/icons/Icon-$size.png').writeAsBytes(await render(size));
        await File('web/icons/Icon-maskable-$size.png')
            .writeAsBytes(await render(size, maskable: true));
      }
      await File('web/favicon.png').writeAsBytes(await render(32));

      const sizes = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256];
      final directory = ByteData(6 + 16 * sizes.length)
        ..setUint16(2, 1, Endian.little)
        ..setUint16(4, sizes.length, Endian.little);
      final images = BytesBuilder();
      for (final (index, size) in sizes.indexed) {
        final png = await render(size);
        final offset = 6 + index * 16;
        directory
          ..setUint8(offset, size % 256)
          ..setUint8(offset + 1, size % 256)
          ..setUint16(offset + 4, 1, Endian.little)
          ..setUint16(offset + 6, 32, Endian.little)
          ..setUint32(offset + 8, png.length, Endian.little)
          ..setUint32(
            offset + 12,
            directory.lengthInBytes + images.length,
            Endian.little,
          );
        images.add(png);
      }
      await File('windows/runner/resources/app_icon.ico').writeAsBytes([
        ...directory.buffer.asUint8List(),
        ...images.takeBytes(),
      ]);
    });
  });
}

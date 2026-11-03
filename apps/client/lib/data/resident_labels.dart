import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:barcode/barcode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

// Millimetres, measured from the approved A4 sample. Coordinates start at the top left.
class LabelLayout {
  static const width = 210.0, height = 297.0, left = 17.0, top = 15.0;
  static const cell = 22.0, columns = 8, perPage = 96;
  static const headerHeight = 12.0, barLeft = 2.1, barTop = 12.1;
  static const barWidth = 17.8, barHeight = 9.0, rule = 0.5 / PdfPageFormat.mm;
  static int pages(int count) => (count + perPage - 1) ~/ perPage;
  static Offset origin(int index) => Offset(
    left + (index % columns) * cell,
    top + ((index % perPage) ~/ columns) * cell,
  );
}

typedef LabelOrder = ({String name, String bed, String barcode, int copies});

class LabelArtwork {
  const LabelArtwork(this.header, this.bars);
  final Uint8List header;
  final List<BarcodeBar> bars;
}

class ResidentLabelDocument {
  ResidentLabelDocument._(this.labels, this.pdf);
  final List<LabelArtwork> labels;
  final Uint8List pdf;

  static Future<ResidentLabelDocument> generate(List<LabelOrder> order) async {
    if (order.isEmpty) throw const FormatException('请至少选择一位长者。');
    final encoder = Barcode.code128();
    final labels = <LabelArtwork>[];
    for (final item in order) {
      if (item.copies < 1 || item.copies > 999) {
        throw const FormatException('每位长者的份数须为 1 至 999。');
      }
      if (item.barcode.isEmpty || !encoder.isValid(item.barcode)) {
        throw FormatException('${item.name}的条码无法用于标签。');
      }
      final bars = encoder
          .make(
            item.barcode,
            width: LabelLayout.barWidth,
            height: LabelLayout.barHeight,
            drawText: false,
          )
          .whereType<BarcodeBar>()
          .where((bar) => bar.black)
          .toList();
      final face = LabelArtwork(await _header(item.name, item.bed), bars);
      labels.addAll(List.filled(item.copies, face));
    }
    return ResidentLabelDocument._(labels, await compute(_writePdf, labels));
  }
}

// Embed the same CJK lettering in preview and PDF, even on a computer without CJK fonts.
// Only the two text lines are rasterized (508 dpi); all printed barcode bars remain vector.
Future<Uint8List> _header(String name, String bed) async {
  const scale = 20.0;
  const width = LabelLayout.cell * scale;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(Colors.white, BlendMode.src);
  void line(String text, double baseline) {
    if (text.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(
        text: text.replaceAll(RegExp(r'[\r\n]+'), ' '),
        style: const TextStyle(
          fontFamily: 'NotoSansSC',
          fontWeight: FontWeight.w600,
          fontSize: 11 / PdfPageFormat.mm * scale,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final fit = math.min(1.0, (width - scale) / painter.width);
    canvas.save();
    canvas.translate((width - painter.width * fit) / 2, baseline * scale);
    canvas.scale(fit);
    painter.paint(
      canvas,
      Offset(
        0,
        -painter.computeDistanceToActualBaseline(TextBaseline.alphabetic),
      ),
    );
    canvas.restore();
    painter.dispose();
  }

  line(name, 4.7);
  line(bed, 10.3);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    width.toInt(),
    (LabelLayout.headerHeight * scale).toInt(),
  );
  picture.dispose();
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('无法绘制标签文字');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}

Future<Uint8List> _writePdf(List<LabelArtwork> labels) async {
  const mm = PdfPageFormat.mm;
  final doc = PdfDocument();
  final headers = <LabelArtwork, PdfImage>{};
  for (var start = 0; start < labels.length; start += LabelLayout.perPage) {
    final canvas = PdfPage(doc, pageFormat: PdfPageFormat.a4).getGraphics();
    for (
      var i = start;
      i < math.min(start + LabelLayout.perPage, labels.length);
      i++
    ) {
      final face = labels[i];
      final at = LabelLayout.origin(i);
      final x = at.dx * mm, top = (LabelLayout.height - at.dy) * mm;
      final header = headers.putIfAbsent(
        face,
        () => PdfImage.file(doc, bytes: face.header),
      );
      canvas.drawImage(
        header,
        x,
        top - LabelLayout.headerHeight * mm,
        LabelLayout.cell * mm,
        LabelLayout.headerHeight * mm,
      );
      canvas.setFillColor(PdfColors.black);
      for (final bar in face.bars) {
        canvas.drawRect(
          x + (LabelLayout.barLeft + bar.left) * mm,
          top - (LabelLayout.barTop + bar.bottom) * mm,
          bar.width * mm,
          bar.height * mm,
        );
      }
      canvas.fillPath();
      canvas.setStrokeColor(const PdfColor(.8, .8, .8));
      canvas.setLineWidth(LabelLayout.rule * mm);
      canvas.drawRect(
        x,
        top - LabelLayout.cell * mm,
        LabelLayout.cell * mm,
        LabelLayout.cell * mm,
      );
      canvas.strokePath();
    }
  }
  return doc.save();
}

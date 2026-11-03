import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillxai_client/data/medicine_image.dart';
import 'package:pillxai_client/data/prescription_repository.dart';
import 'package:pillxai_client/models/demo_model.dart';
import 'package:pillxai_client/widgets/prescription_forms.dart';

void main() {
  testWidgets(
    'photo becomes bounded PNG and round trips through prescription contract',
    (tester) async {
      final photo = await tester.runAsync(() async {
        final source = await rootBundle.load('assets/images/medicine-a.png');
        final result = await thumbnailMedicineImage(
          source.buffer.asUint8List(),
        );
        final bytes = base64Decode(result.split(',').last);
        expect(bytes.length, lessThanOrEqualTo(1100000));
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, lessThanOrEqualTo(512));
        expect(frame.image.height, lessThanOrEqualTo(512));
        frame.image.dispose();
        codec.dispose();
        return result;
      });
      final medicine = Medicine(
        id: 'm',
        name: '测试药',
        strength: '1 mg',
        startDate: DateTime(2026, 11, 2),
        imageAsset: photo,
      );
      expect(medicineToApi(medicine).image, photo);
      expect(medicineImageProvider(photo), isA<MemoryImage>());
    },
  );

  for (final source in MedicineImageSource.values) {
    testWidgets('medicine picker source $source stays draft until save', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = DemoModel(autoTick: false);
      addTearDown(model.dispose);
      final resident = model.residents.first;
      final medicine = resident.medicines.first;
      Medicine? saved;
      MedicineImageSource? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicineForm(
              resident: resident,
              medicine: medicine,
              bedtimeEnabled: true,
              chooseImage: (value) async {
                selected = value;
                return 'assets/images/medicine-b.png';
              },
              onSave: (value) => saved = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('upload-medicine-image')));
      await tester.pumpAndSettle();
      expect(find.text('拍照'), findsOneWidget);
      expect(find.text('从文件上传'), findsOneWidget);
      await tester.tap(
        find.text(source == MedicineImageSource.camera ? '拍照' : '从文件上传'),
      );
      await tester.pumpAndSettle();
      expect(selected, source);
      expect(medicine.imageAsset, 'assets/images/medicine-a.png');
      expect(saved, isNull);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(saved?.imageAsset, 'assets/images/medicine-b.png');
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
}

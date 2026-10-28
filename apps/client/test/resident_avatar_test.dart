import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillxai_client/data/resident_avatar.dart';
import 'package:pillxai_client/models/demo_model.dart';
import 'package:pillxai_client/widgets/prescription_forms.dart';
import 'package:pillxai_client/widgets/profile_avatar.dart';

void main() {
  testWidgets('uploaded image becomes a bounded PNG thumbnail', (tester) async {
    final result = await tester.runAsync(() async {
      final source = await rootBundle.load(residentAvatarPresets.first);
      final encoded = await thumbnailAvatar(source.buffer.asUint8List());
      final bytes = base64Decode(encoded.split(',').last);
      expect(bytes.length, lessThanOrEqualTo(270000));
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, lessThanOrEqualTo(256));
      expect(frame.image.height, lessThanOrEqualTo(256));
      frame.image.dispose();
      codec.dispose();
      return encoded;
    });
    expect(result, startsWith('data:image/png;base64,'));
  });

  for (final upload in [false, true]) {
    testWidgets('avatar remains a draft until save: upload=$upload', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = DemoModel(autoTick: false);
      addTearDown(model.dispose);
      final resident = model.residents.first;
      final before = resident.avatarAsset;
      Resident? saved;
      // Picker boundary injected; image normalization is covered above.
      final chosen = upload
          ? residentAvatarPresets.last
          : residentAvatarPresets[1];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResidentForm(
              model: model,
              resident: resident,
              chooseAvatar: () async => chosen,
              onSave: (draft) {
                saved = draft;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        upload
            ? find.text('上传头像')
            : find.byKey(const ValueKey('avatar-preset-1')),
      );
      await tester.pumpAndSettle();
      expect(resident.avatarAsset, before);
      expect(saved, isNull);
      final preview = tester.widget<ProfileAvatar>(
        find.byWidgetPredicate(
          (w) => w is ProfileAvatar && w.label == '长者头像预览',
        ),
      );
      expect(preview.asset, chosen);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(saved?.avatarAsset, chosen);
    });
  }

  testWidgets('cancelled image picker preserves current avatar', (
    tester,
  ) async {
    final model = DemoModel(autoTick: false);
    addTearDown(model.dispose);
    final resident = model.residents.first;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResidentForm(
            model: model,
            resident: resident,
            chooseAvatar: () async => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('上传头像'));
    await tester.pumpAndSettle();
    final preview = tester.widget<ProfileAvatar>(
      find.byWidgetPredicate((w) => w is ProfileAvatar && w.label == '长者头像预览'),
    );
    expect(preview.asset, resident.avatarAsset);
    expect(find.textContaining('图片无法读取'), findsNothing);
  });
}

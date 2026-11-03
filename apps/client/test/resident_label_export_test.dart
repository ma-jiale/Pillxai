import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillxai_client/data/prescription_repository.dart';
import 'package:pillxai_client/data/resident_labels.dart';
import 'package:pillxai_client/models/prescription_controller.dart';
import 'package:pillxai_client/models/prescription_store.dart';
import 'package:pillxai_client/screens/prescriptions_page.dart';

import 'connected_prescriptions_test.dart' show connection, jsonResponse;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('NotoSansSC')
          ..addFont(rootBundle.load('assets/fonts/NotoSansCJKsc-Regular.otf')))
        .load();
  });

  testWidgets('工作人员勾选与修改份数，跨页预览后取消、失败和重试使用同份 PDF', (tester) async {
    tester.view.physicalSize = const Size(1100, 750);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backend = connection((_) async => jsonResponse([]));
    final model =
        PrescriptionController(
            PrescriptionRepository(backend),
            bedtime: false,
            canEdit: false,
          )
          ..residents = [
            Resident(
              id: 'a',
              name: '陈明华',
              bed: '2101',
              medicines: [],
              barcode: '008101',
            ),
            Resident(
              id: 'b',
              name: '林秀英',
              bed: '',
              medicines: [],
              barcode: '008102',
            ),
            Resident(id: 'c', name: '无条码长者', bed: '', medicines: []),
          ];
    addTearDown(backend.dispose);
    addTearDown(model.dispose);
    final captured = <Uint8List>[];
    const channel = MethodChannel('pillxai/pdf');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'save');
      captured.add(call.arguments['bytes'] as Uint8List);
      if (captured.length == 1) return null;
      if (captured.length == 2) throw PlatformException(code: 'save');
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PrescriptionsPage(model: model)),
      ),
    );
    await tester.tap(find.text('导出标签'));
    await tester.pumpAndSettle();
    FilledButton generateButton() =>
        tester.widget(find.widgetWithText(FilledButton, '生成预览'));
    expect(generateButton().onPressed, isNull);
    await tester.tap(find.text('全选当前结果'));
    await tester.pumpAndSettle();
    expect(find.text('已选 2 位长者 · 2 张 · 1 页 A4'), findsOneWidget);
    final qty = find.byKey(const ValueKey('copies-b'));
    await tester.enterText(qty, '0');
    await tester.pump();
    expect(generateButton().onPressed, isNull);
    await tester.enterText(qty, '95');
    await tester.enterText(find.byKey(const ValueKey('copies-a')), '2');
    await tester.pump();
    expect(find.text('已选 2 位长者 · 97 张 · 2 页 A4'), findsOneWidget);
    await tester.runAsync(() async {
      final generate = generateButton().onPressed! as Future<void> Function();
      await generate();
    });
    await tester.pumpAndSettle();
    expect(find.text('第 1 / 2 页'), findsOneWidget);
    await tester.tap(find.byTooltip('下一页'));
    await tester.pumpAndSettle();
    expect(find.text('第 2 / 2 页'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('导出 PDF'));
      await tester.pumpAndSettle();
      if (i == 0) expect(find.text('PDF 已导出。'), findsNothing);
      if (i == 1) expect(find.textContaining('保存失败'), findsOneWidget);
    }
    expect(find.text('PDF 已导出。'), findsOneWidget);
    expect(captured, hasLength(3));
    expect(captured.every((p) => p.length == captured.first.length), isTrue);
    expect(captured.last, orderedEquals(captured.first));
    expect(String.fromCharCodes(captured.last.take(5)), '%PDF-');
    if (const bool.fromEnvironment('LABEL_PROOF')) {
      File('../../.tools/tmp/label-proof/client-97.pdf')
          .writeAsBytesSync(captured.last);
    }
    await tester.tap(find.text('修改选择'));
    await tester.pumpAndSettle();
    expect(find.text('已选 2 位长者 · 97 张 · 2 页 A4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('无选择、无条码和非法份数不能生成标签', () async {
    await expectLater(
      ResidentLabelDocument.generate([]),
      throwsFormatException,
    );
    for (final pair in [('', 1), ('000010', 0), ('000010', 1000)]) {
      await expectLater(
        ResidentLabelDocument.generate([
          (name: '测试', bed: '', barcode: pair.$1, copies: pair.$2),
        ]),
        throwsFormatException,
      );
    }
  });
}

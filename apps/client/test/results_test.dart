import 'support/tasks.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillxai_client/main.dart';
import 'package:pillxai_client/models/demo_model.dart';

DemoModel runningTask() {
  final model = DemoModel(autoTick: false);
  startTestTask(model, counts: [2, 2, 2], start: DateTime(2026, 10, 25));
  return model;
}

void main() {
  test('结束快照不可被处方修改；人工数量独立保存，取盒完成前禁止新任务', () {
    final model = runningTask();
    addTearDown(model.dispose);
    model.advance();
    model.advance();
    model.advance();
    model.skipCurrent(markPrepared: true);
    model.advance();
    model.advance();
    final snapshot = model.currentRecord!;
    expect(snapshot.outcome, TaskOutcome.completed);
    expect(snapshot.medicines[1].result.countedParticles, 1);
    expect(snapshot.medicines[1].result.confirmedParticles, 2);
    expect(model.demoCoverage['r1'], DateTime(2026, 10, 31));
    model.advance();
    model.cancel();
    model.skipRemaining();
    expect(model.records.length, 1);
    expect(model.startPreparedTask(model.planFor(model.residents[1])), isFalse);
    expect(model.startPreparedTask(model.planFor(model.residents[1])), isFalse);
    model.residents.first.name = '修改后的姓名';
    expect(snapshot.name, '王奶奶');
    model.updateCollectionFeedback(
      recordId: snapshot.id,
      boxOnTrack: true,
      trackReady: true,
    );
    expect(model.busy, isTrue);
    model.updateCollectionFeedback(
      recordId: 'stale-task',
      boxOnTrack: false,
      trackReady: true,
    );
    expect(model.busy, isTrue);
    model.updateCollectionFeedback(recordId: snapshot.id, boxOnTrack: false);
    model.updateCollectionFeedback(recordId: snapshot.id, boxOnTrack: false);
    expect(
      model.currentRecord!.events
          .where((e) => e.description.contains('药盒已离轨'))
          .length,
      1,
    );
    expect(model.busy, isTrue);
    model.updateCollectionFeedback(
      recordId: snapshot.id,
      boxOnTrack: false,
      trackReady: true,
    );
    expect(model.busy, isFalse);
    expect(model.records.single.collection, CollectionStage.complete);
    expect(model.startPreparedTask(model.planFor(model.residents[1])), isTrue);
    expect(snapshot.medicines[1].result.confirmedParticles, 2);
    expect(model.records.length, 1);
  });

  test('取消保留已完成与当前计数，未知结果不计覆盖；失败重试不改变结果', () {
    final model = runningTask();
    addTearDown(model.dispose);
    model.advance();
    model.advance();
    model.advance();
    model.cancel();
    final result = model.currentRecord!;
    expect(result.outcome, TaskOutcome.cancelled);
    expect(result.medicines.map((m) => m.result.outcome), [
      MedicineOutcome.completed,
      MedicineOutcome.unverified,
      MedicineOutcome.notStarted,
    ]);
    expect(result.medicines[1].result.countedParticles, 1);
    expect(model.demoCoverage['r1'], isNull);
    model.updateCollectionFeedback(
      recordId: result.id,
      boxOnTrack: null,
      trackReady: true,
    );
    expect(model.currentRecord!.collection, CollectionStage.detectionFailed);
    expect(model.busy, isTrue);
    model.updateCollectionFeedback(recordId: result.id, boxOnTrack: false);
    model.updateCollectionFeedback(
      recordId: result.id,
      boxOnTrack: false,
      retractionFailed: true,
    );
    expect(model.currentRecord!.collection, CollectionStage.retractionFailed);
    model.updateCollectionFeedback(
      recordId: result.id,
      boxOnTrack: true,
      trackReady: true,
    );
    expect(model.busy, isTrue);
    model.updateCollectionFeedback(
      recordId: result.id,
      boxOnTrack: false,
      trackReady: true,
    );
    expect(model.records.single.medicines, result.medicines);
    expect(model.records.single.outcome, TaskOutcome.cancelled);
    expect(model.busy, isFalse);
    expect(model.records.length, 1);
  });

  test('跳过最后一药保留部分结果，示例可重复加载但不产生重复记录', () {
    final model = runningTask();
    addTearDown(model.dispose);
    for (var i = 0; i < 4; i++) {
      model.advance();
    }
    model.skipRemaining();
    expect(model.currentRecord!.outcome, TaskOutcome.partial);
    expect(model.currentRecord!.completedCount, 2);
    expect(model.demoCoverage['r1'], isNull);
    model.loadExampleRecords();
    model.loadExampleRecords();
    expect(model.records.length, 4);
    expect(model.openExampleCollection('example-0'), isFalse);
  });

  setUpAll(() async {
    await (FontLoader('NotoSansSC')
          ..addFont(rootBundle.load('assets/fonts/NotoSansCJKsc-Regular.otf')))
        .load();
    await (FontLoader('MaterialIcons')..addFont(
          File(
            '../../.tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        ))
        .load();
  });

  for (final size in [
    const Size(1280, 800),
    const Size(1024, 600),
    const Size(390, 844),
  ]) {
    testWidgets('结果、取盒、历史查询与详情闭环 $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = runningTask();
      addTearDown(model.dispose);
      for (var i = 0; i < 4; i++) {
        model.advance();
      }
      model.skipRemaining();
      const root = ValueKey('results-capture-root');
      await tester.pumpWidget(
        RepaintBoundary(
          key: root,
          child: PillxaiApp(model: model, initiallySignedIn: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final resident in model.residents) {
          if (resident.avatarAsset != null) {
            await precacheImage(
              AssetImage(resident.avatarAsset!),
              tester.element(find.byType(PillxaiApp)),
            );
          }
        }
      });
      await tester.pumpAndSettle();
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      Future<void> capture(String name) async {
        const folder = String.fromEnvironment('RESULTS_CAPTURE');
        if (folder.isEmpty) return;
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(root),
          );
          final picture = await boundary.toImage(pixelRatio: 1);
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          Directory(folder).createSync(recursive: true);
          File('$folder/${size.width.toInt()}-$name.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          picture.dispose();
        });
      }

      expect(find.text('请取出药盒，等待设备反馈 · 演练'), findsOneWidget);
      expect(find.text('王奶奶 · 部分完成'), findsOneWidget);
      expect(find.byKey(const ValueKey('prepare-r1')), findsOneWidget);
      expect(find.byKey(const ValueKey('confirm-removal')), findsNothing);
      await capture('result');
      await tap(find.byKey(const ValueKey('result-details')));
      expect(find.text('逐药结果'), findsOneWidget);
      expect(find.text('已跳过'), findsOneWidget);
      await capture('details');
      await tap(find.byTooltip('关闭结果详情'));
      final recordId = model.currentRecord!.id;
      model.updateCollectionFeedback(recordId: recordId, boxOnTrack: null);
      await tester.pumpAndSettle();
      expect(find.text('药盒状态暂不可用，等待设备恢复 · 演练'), findsOneWidget);
      model.updateCollectionFeedback(recordId: recordId, boxOnTrack: false);
      await tester.pumpAndSettle();
      expect(find.text('药盒已离轨，等待轨道就绪 · 演练'), findsOneWidget);
      model.updateCollectionFeedback(
        recordId: recordId,
        boxOnTrack: false,
        trackReady: true,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('collection-status')), findsNothing);
      expect(model.busy, isFalse);
      await capture('collected');
      expect(find.byKey(const ValueKey('prepare-r1')), findsOneWidget);
      await tap(find.byKey(const ValueKey('open-history')));
      expect(find.byKey(const ValueKey('history-session-1')), findsOneWidget);
      model.loadExampleRecords();
      await tester.pumpAndSettle();
      await capture('history');
      await tester.enterText(
        find.byKey(const ValueKey('history-search')),
        '不存在的姓名',
      );
      await tap(find.text('查询'));
      expect(find.text('没有符合条件的记录'), findsOneWidget);
      await tap(find.text('清除').first);
      await tester.enterText(
        find.byKey(const ValueKey('history-search')),
        '208',
      );
      await tap(find.text('查询'));
      expect(find.text('共 2 条'), findsOneWidget);
      await tap(find.byKey(const ValueKey('history-session-1')));
      expect(find.text('逐药结果'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('从历史空页载入示例、筛选、取盒与跨页恢复', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = DemoModel(autoTick: false);
    addTearDown(model.dispose);
    await tester.pumpWidget(PillxaiApp(model: model, initiallySignedIn: true));
    await tester.pumpAndSettle();
    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tap(find.byKey(const ValueKey('open-history')));
    expect(find.text('暂无摆药记录'), findsOneWidget);
    await tap(find.byKey(const ValueKey('load-examples')));
    expect(model.records.length, 3);
    await tap(find.text('全部结果'));
    await tap(find.widgetWithText(MenuItemButton, '待核实'));
    expect(find.text('共 1 条'), findsOneWidget);
    expect(find.byKey(const ValueKey('history-example-2')), findsOneWidget);
    await tap(find.text('清除').first);
    await tap(find.byKey(const ValueKey('history-example-0')));
    await tap(find.byKey(const ValueKey('preview-collection')));
    expect(find.text('请取出药盒，等待设备反馈 · 演练'), findsOneWidget);
    await tap(find.text('处方管理'));
    expect(find.text('王奶奶 · 等待取盒   ↗'), findsNothing);
    await tap(find.byKey(const ValueKey('resident-history-r1')));
    expect(find.text('共 1 条'), findsOneWidget);
    await tap(find.byKey(const ValueKey('close-history')));
    await tap(find.text('摆药'));
    expect(find.byKey(const ValueKey('prepare-r1')), findsOneWidget);
    expect(find.byKey(const ValueKey('confirm-removal')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(model.currentRecord, isNull);
    expect(
      model.records.firstWhere((r) => r.id == 'example-0').collection,
      CollectionStage.complete,
    );
    expect(find.byKey(const ValueKey('collection-status')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scan_and_collection_test.dart' show login;

void main() {
  testWidgets('Android 恢复窗口焦点保持摆药界面，从后台返回才刷新', (tester) async {
    final fixture = await login(tester);
    await tester.tap(find.text('开始摆药'));
    await tester.pumpAndSettle();

    final queueReads = fixture.queueReads;
    final previewReads = fixture.previewReads;
    fixture.host.operations.clear();
    final change = tester.binding.handleAppLifecycleStateChanged;
    change(AppLifecycleState.inactive);
    change(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(fixture.queueReads, queueReads);
    expect(fixture.previewReads, previewReads);
    expect(fixture.host.operations, isNot(contains('view')));

    change(AppLifecycleState.inactive);
    change(AppLifecycleState.hidden);
    change(AppLifecycleState.paused);
    change(AppLifecycleState.hidden);
    change(AppLifecycleState.inactive);
    change(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(fixture.queueReads, queueReads + 1);
    expect(fixture.previewReads, previewReads + 1);
    expect(fixture.host.operations.where((op) => op == 'view'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

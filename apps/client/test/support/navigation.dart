import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openSettings(WidgetTester tester) async {
  final account = find.byKey(const ValueKey('account-menu'));
  await tester.ensureVisible(account);
  await tester.tap(account);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(MenuItemButton, '设置'));
  await tester.pumpAndSettle();
}

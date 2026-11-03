import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillxai_client/screens/count_review_dialog.dart';

import 'scan_and_collection_test.dart' show login;

void main() {
  for (final last in [false, true]) {
    testWidgets(
      'machine error opens one review and waits for confirmation, last=$last',
      (tester) async {
        final fixture = await login(tester);
        final host = fixture.host;
        host.value['task'] = fixture.task;
        final batch = last ? (fixture.task['batches'] as List).length - 1 : 0;
        host.feedback('openingForReview', batch: batch, count: 3);
        await tester.pumpAndSettle();
        expect(find.byType(CountReviewDialog), findsOneWidget);
        final label = last ? '已核对，结束摆药' : '已核对，继续下一药';
        expect(find.text(label), findsNothing);
        host.feedback('reviewingCount');
        await tester.pumpAndSettle();
        expect(find.textContaining('机器最后报告 3 颗'), findsOneWidget);
        expect(
          find
              .textContaining('月', findRichText: false)
              .evaluate()
              .where(
                (element) =>
                    (element.widget as Text).data?.contains('颗') == true,
              ),
          isNotEmpty,
        );
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, label))
              .onPressed,
          isNull,
        );
        await tester.binding.handlePopRoute();
        host.value['can_confirm_count_review'] = true;
        host.events.add(host.value);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(
          host.operations.where((op) => op == 'confirm_count_review'),
          hasLength(1),
        );
        host.feedback(
          last ? 'collecting' : 'running',
          batch: last ? batch : batch + 1,
        );
        await tester.pumpAndSettle();
        expect(find.byType(CountReviewDialog), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

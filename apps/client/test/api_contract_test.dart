import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pillxai_api_client/api.dart';

void main() {
  test('generated contract preserves half tablets, dates, timezone and nulls', () {
    final fixture = jsonDecode(File('../../tests/fixtures/contract-sample.json').readAsStringSync());
    final sample = ContractSample.fromJson(fixture)!;
    final serialized = jsonDecode(jsonEncode(sample.toJson())) as Map<String, dynamic>;
    expect(serialized['original_tablets'], '0.5');
    expect(serialized['particles'], 1);
    expect(serialized['feed_form'], 'half');
    expect(serialized['start_date'], '2026-10-26');
    expect(serialized.containsKey('end_date'), isTrue);
    expect(serialized['end_date'], isNull);
    expect(serialized.containsKey('note'), isTrue);
    expect(serialized['note'], isNull);
    expect(DateTime.parse(serialized['observed_at']), DateTime.utc(2026, 10, 26, 1));
    expect(ContractSample.fromJson(serialized), sample);
  });
}

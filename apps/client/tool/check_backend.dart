import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:pillxai_api_client/api.dart';

/// Runs from the actual Flutter package against the WSL service and PostgreSQL.
/// This is a development contract check, never a production prescription write.
Future<void> main(List<String> arguments) async {
  final client = ApiClient(basePath: arguments.isEmpty ? 'http://127.0.0.1:8000' : arguments.first);
  try {
    final ready = await DefaultApi(client).getReadiness();
    if (ready?.status != 'ready') throw StateError('Backend is not ready');
    final fixture = jsonDecode(File('../../tests/fixtures/contract-sample.json').readAsStringSync()) as Map<String, dynamic>;
    final random = Random.secure();
    final hex = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    fixture['sample_id'] = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    final sample = ContractSample.fromJson(fixture)!;
    final api = ContractApi(client);
    final saved = await api.saveContractSample(SaveContractSample(expectedRevision: 0, sample: sample));
    final loaded = await api.getContractSample(sample.sampleId);
    if (saved?.revision != 1 || loaded?.sample != sample) {
      throw StateError('Cross-language contract round trip changed the sample');
    }
    try {
      await api.saveContractSample(SaveContractSample(expectedRevision: 0, sample: sample));
      throw StateError('Stale revision was accepted');
    } on ApiException catch (error) {
      if (error.code != 409 || ApiError.fromJson(jsonDecode(error.message!))?.code != 'revision_conflict') rethrow;
    }
    stdout.writeln(jsonEncode({'result': 'passed', 'sample_id': sample.sampleId, 'revision': loaded!.revision, 'checks': ['database_readiness', 'nullable_fields', 'business_dates', 'offset_timestamp', 'decimal_string', 'enum', 'revision_conflict']}));
  } finally { client.client.close(); }
}

// Real HTTP smoke check, using only the generated SDK (no Flutter/mock transport).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:pillxai_api_client/api.dart';

String newId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  final credentials = jsonDecode(
    await File('../../.var/local-login.json').readAsString(),
  ) as Map;
  final login = (credentials['accounts'] as List).cast<Map>().firstWhere(
    (row) =>
        row['username'] ==
        (credentials['administrator_username'] ?? 'local-admin'),
  );
  var client = ApiClient(basePath: 'http://127.0.0.1:8000');
  Future<void> signIn() async {
    final result = await IdentityApi(client).login(
      Login(
        username: login['username'] as String,
        password: login['password'] as String,
      ),
    );
    check(result != null, 'Missing login response');
    client.addDefaultHeader('Authorization', 'Bearer ${result!.accessToken}');
  }

  try {
    await signIn();
    final residentId = newId();
    final prescriptionId = newId();
    final resident = await ResidentsApi(client).saveResident(
      residentId,
      SaveResident(
        expectedRevision: 0,
        data: ResidentData(name: '联调虚构长者', bed: ''),
      ),
    );
    check(resident?.revision == 1, 'Resident not saved');
    final data = PrescriptionData(
      medicineName: '联调虚构药物',
      strength: '10 mg',
      unit: DoseUnit.tablet,
      feedForm: FeedForm.half,
      doses: DoseAmounts(morning: '0.5', noon: '0', evening: '0.5', night: '0'),
      mealRelation: MealRelation.after,
      startDate: DateTime(2026, 10, 26),
      endDate: null,
    );
    final first = await PrescriptionsApi(client).savePrescription(
      residentId,
      prescriptionId,
      SavePrescription(expectedRevision: 0, data: data),
    );
    check(
      first?.revision == 1 && first?.data.endDate == null,
      'Prescription contract mismatch',
    );
    final stopped = await PrescriptionsApi(client).savePrescription(
      residentId,
      prescriptionId,
      SavePrescription(expectedRevision: 1, data: data.copyWith(stopped: true)),
    );
    check(stopped?.revision == 2, 'Stop not versioned');
    final restored = await PrescriptionsApi(client).savePrescription(
      residentId,
      prescriptionId,
      SavePrescription(expectedRevision: 2, data: data),
    );
    check(
      restored?.revision == 3 && restored?.medicineId == first?.medicineId,
      'Identity changed on restore',
    );
    try {
      await PrescriptionsApi(client).savePrescription(
        residentId,
        prescriptionId,
        SavePrescription(expectedRevision: 1, data: data),
      );
      throw StateError('Stale write was accepted');
    } on ApiException catch (error) {
      check(error.code == 409, 'Expected revision conflict');
    }
    await IdentityApi(client).logout();
    client.client.close();
    client = ApiClient(basePath: 'http://127.0.0.1:8000');
    await signIn();
    final versions = await PrescriptionsApi(client)
        .listPrescriptionVersions(residentId, prescriptionId);
    check(
      versions?.length == 3 && versions!.last.data.doses.morning == '0.5',
      'History lost after new client',
    );
    await IdentityApi(client).logout();
    stdout.writeln(
      jsonEncode({
        'result': 'passed',
        'resident_id': residentId,
        'prescription_id': prescriptionId,
        'checks': [
          'login',
          'resident_save',
          'half_dose',
          'nullable_end_date',
          'stop_restore_versions',
          'conflict',
          'new_client_history',
          'logout',
        ],
      }),
    );
  } finally {
    client.client.close();
  }
}

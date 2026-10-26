// Real SDK / HTTP / PostgreSQL check. Adds only clearly labelled fictional data.
import 'dart:convert';
import 'dart:io';

import 'package:pillxai_api_client/api.dart';

import 'check_business.dart' show newId, check;

SaveSettings payload(AppSettings settings, int revision, {int? days}) =>
    SaveSettings(
      expectedRevision: revision,
      preparationDays: days ?? settings.preparationDays,
      splitMeals: settings.splitMeals,
      bedtimeEnabled: settings.bedtimeEnabled,
      startTomorrow: settings.startTomorrow,
    );

Future<void> main() async {
  final file = jsonDecode(
    await File('../../.var/local-login.json').readAsString(),
  ) as Map;
  final credentials = (file['accounts'] as List).cast<Map>().firstWhere(
    (row) => row['username'] == 'local-admin',
  );
  final client = ApiClient(basePath: 'http://127.0.0.1:8000');
  AppSettings? original;
  AppSettings? saved;
  try {
    final login = (await IdentityApi(client).login(
      Login(
        username: credentials['username'],
        password: credentials['password'],
      ),
    ))!;
    client.addDefaultHeader('Authorization', 'Bearer ${login.accessToken}');
    final settingsApi = SettingsApi(client);
    original = (await settingsApi.getSettings())!;
    saved = (await settingsApi.saveSettings(
      payload(original, original.revision, days: 2),
    ))!;
    check(
      saved.revision == original.revision + 1 && saved.preparationDays == 2,
      'Settings save failed',
    );
    final rid = newId();
    await ResidentsApi(client).saveResident(
      rid,
      SaveResident(
        expectedRevision: 0,
        data: ResidentData(name: '计划联调虚构长者', bed: ''),
      ),
    );
    for (final half in [true, false]) {
      await PrescriptionsApi(client).savePrescription(
        rid,
        newId(),
        SavePrescription(
          expectedRevision: 0,
          data: PrescriptionData(
            medicineName: half ? '虚构半片药物' : '虚构整片药物',
            strength: '10 mg',
            unit: DoseUnit.tablet,
            feedForm: half ? FeedForm.half : FeedForm.whole,
            doses: DoseAmounts(
              morning: half ? '0.5' : '2',
              noon: '0',
              evening: half ? '0.5' : '0',
              night: '0',
            ),
            mealRelation: half ? MealRelation.before : MealRelation.after,
            startDate: DateTime(2026, 10, 26),
            endDate: null,
          ),
        ),
      );
    }
    final planning = PlanningApi(client);
    final result = (await planning.createPlanPreview(
      rid,
      PreviewRequest(days: 3, splitMeals: true),
    ))!;
    final snapshot = result.snapshot;
    check(
      result.current &&
          snapshot.dates.length == 3 &&
          snapshot.trays.length == 2,
      'Preview contract mismatch',
    );
    check(
      snapshot.trays.first.medicines.single.totalParticles == 6,
      'Half particle conversion failed',
    );
    check(
      snapshot.trays.first.medicines.single.originalUnits == '3',
      'Original units failed',
    );
    check(
      snapshot.trays.last.medicines.single.totalParticles == 6,
      'Whole particles failed',
    );
    check(
      (await settingsApi.getSettings())!.preparationDays == 2,
      'Per-preview override changed settings',
    );
    // New SDK instance and session independently reload saved settings and snapshot.
    final reopened = ApiClient(basePath: client.basePath);
    try {
      final login2 = (await IdentityApi(reopened).login(
        Login(
          username: credentials['username'],
          password: credentials['password'],
        ),
      ))!;
      reopened.addDefaultHeader(
        'Authorization',
        'Bearer ${login2.accessToken}',
      );
      check(
        (await SettingsApi(reopened).getSettings())!.revision == saved.revision,
        'Settings reload mismatch',
      );
      check(
        (await PlanningApi(reopened).getPlanPreview(snapshot.id))!.snapshot ==
            snapshot,
        'Snapshot reload mismatch',
      );
      await IdentityApi(reopened).logout();
    } finally {
      reopened.client.close();
    }
    await settingsApi.saveSettings(payload(original, saved.revision));
    saved = null;
    final stale = (await planning.getPlanPreview(snapshot.id))!;
    check(
      !stale.current && stale.snapshot == snapshot,
      'Settings change must invalidate, never rewrite history',
    );
    stdout.writeln(
      jsonEncode({
        'result': 'passed',
        'resident_id': rid,
        'plan_id': snapshot.id,
        'checks': [
          'settings_save_reload',
          'real_prescriptions',
          'server_preview',
          'half_and_whole_particles',
          'date_array_sdk',
          'meal_trays',
          'preview_override',
          'immutable_snapshot',
          'settings_invalidation',
          'original_settings_restored',
        ],
      }),
    );
    await IdentityApi(client).logout();
  } finally {
    // CAS intentionally refuses to overwrite another administrator's concurrent change.
    if (saved != null && original != null) {
      await SettingsApi(client).saveSettings(payload(original, saved.revision));
    }
    client.client.close();
  }
}

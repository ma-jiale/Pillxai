import 'package:pillxai_api_client/api.dart' as api;

import '../models/prescription_store.dart';
import 'backend_connection.dart';

/// Maps generated HTTP contracts into UI models; it has no execution/database dependency.
class PrescriptionRepository {
  PrescriptionRepository(this.backend);
  final BackendConnection backend;

  Future<List<Resident>> listResidents() async {
    final result = <Resident>[];
    String? after;
    do {
      final page = await backend.request(
        backend.residents.listResidents(after: after),
      );
      if (page == null) throw const SaveFailure('长者列表响应不完整，请刷新。');
      result.addAll(page.items.map(residentFromApi));
      after = page.nextAfter;
    } while (after != null);
    return result;
  }

  Future<List<Medicine>> listMedicines(String residentId) async =>
      (await backend.request(
                backend.prescriptions.listPrescriptions(residentId),
              ) ??
              (throw const SaveFailure('用药列表响应不完整，请刷新。')))
          .map(medicineFromApi)
          .toList();

  Future<Resident> saveResident(Resident resident) async {
    final saved = await backend.request(
      backend.residents.saveResident(
        resident.id,
        api.SaveResident(
          expectedRevision: resident.revision,
          data: api.ResidentData(name: resident.name, bed: resident.bed),
        ),
      ),
    );
    if (saved == null) throw const SaveFailure('保存结果尚未确认，请刷新核对。');
    return residentFromApi(saved);
  }

  Future<Medicine> saveMedicine(String residentId, Medicine medicine) async {
    final saved = await backend.request(
      backend.prescriptions.savePrescription(
        residentId,
        medicine.id,
        api.SavePrescription(
          expectedRevision: medicine.revision,
          data: medicineToApi(medicine),
        ),
      ),
    );
    if (saved == null) throw const SaveFailure('保存结果尚未确认，请刷新核对。');
    return medicineFromApi(saved);
  }

  Future<List<api.PrescriptionView>> versions(
    String residentId,
    String medicineId,
  ) async =>
      await backend.request<List<api.PrescriptionView>?>(
        backend.prescriptions.listPrescriptionVersions(residentId, medicineId),
      ) ??
      (throw const SaveFailure('版本记录读取失败，请重试。'));
}

Resident residentFromApi(api.ResidentView row) => Resident(
  id: row.id,
  name: row.data.name,
  bed: row.data.bed,
  medicines: [],
  revision: row.revision,
);

const mealLabels = {
  api.MealRelation.before: '饭前',
  api.MealRelation.after: '饭后',
  api.MealRelation.withMeal: '随餐',
  api.MealRelation.unrestricted: '无餐食限制',
};

Medicine medicineFromApi(api.PrescriptionView row) {
  final data = row.data;
  return Medicine(
    id: row.id,
    name: data.medicineName,
    strength: data.strength,
    revision: row.revision,
    unit: data.unit == api.DoseUnit.tablet ? '片' : '粒',
    form: data.feedForm == api.FeedForm.half
        ? '预切半片'
        : data.unit == api.DoseUnit.tablet
        ? '整片'
        : '整粒',
    doses: DoseSchedule(
      morning: double.parse(data.doses.morning),
      noon: double.parse(data.doses.noon),
      evening: double.parse(data.doses.evening),
      night: double.parse(data.doses.night),
    ),
    meal: mealLabels[data.mealRelation]!,
    startDate: data.startDate,
    endDate: data.endDate,
    stopped: data.stopped,
  );
}

api.PrescriptionData medicineToApi(Medicine medicine) => api.PrescriptionData(
  medicineName: medicine.name,
  strength: medicine.strength,
  unit: medicine.unit == '片' ? api.DoseUnit.tablet : api.DoseUnit.capsule,
  feedForm: medicine.form == '预切半片' ? api.FeedForm.half : api.FeedForm.whole,
  doses: api.DoseAmounts(
    morning: formatDose(medicine.doses.morning),
    noon: formatDose(medicine.doses.noon),
    evening: formatDose(medicine.doses.evening),
    night: formatDose(medicine.doses.night),
  ),
  mealRelation: mealLabels.entries
      .firstWhere((entry) => entry.value == medicine.meal)
      .key,
  startDate: medicine.startDate!,
  endDate: medicine.endDate,
  stopped: medicine.stopped,
);

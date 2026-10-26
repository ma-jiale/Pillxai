import 'package:flutter/foundation.dart';

import '../data/prescription_repository.dart';
import 'prescription_store.dart';

/// Owns workspace query state independently of page lifetimes.
class PrescriptionController extends ChangeNotifier
    implements PrescriptionStore {
  PrescriptionController(
    this.repository, {
    required this.bedtime,
    required this.canEdit,
  });
  final PrescriptionRepository repository;
  @override
  bool bedtime;
  void updateBedtime(bool value) {
    if (bedtime == value || _disposed) return;
    bedtime = value;
    notifyListeners();
  }

  @override
  final bool canEdit;
  @override
  List<Resident> residents = [];
  @override
  String? selectedResidentId;
  bool loading = false;
  String? error;
  int _generation = 0;
  bool _disposed = false;

  Future<void> refresh() async {
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final loaded = await repository.listResidents();
      if (!_current(generation)) return;
      residents = loaded;
      if (!residents.any((row) => row.id == selectedResidentId)) {
        selectedResidentId = residents.firstOrNull?.id;
      }
      if (selectedResidentId != null) {
        final medicines = await repository.listMedicines(selectedResidentId!);
        if (!_current(generation)) return;
        residents
            .firstWhere((row) => row.id == selectedResidentId)
            .medicines
            .addAll(medicines);
      }
    } catch (failure) {
      if (_current(generation)) error = failure.toString();
    } finally {
      if (_current(generation)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void selectResident(String id) {
    if (id == selectedResidentId) return;
    selectedResidentId = id;
    _loadSelected(id);
  }

  Future<void> _loadSelected(String id) async {
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final medicines = await repository.listMedicines(id);
      if (!_current(generation)) return;
      residents.firstWhere((row) => row.id == id).medicines
        ..clear()
        ..addAll(medicines);
    } catch (failure) {
      if (_current(generation)) error = failure.toString();
    } finally {
      if (_current(generation)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  @override
  Resident? bedConflict(String bed, {String? excludingId}) => bed.trim().isEmpty
      ? null
      : residents
            .where(
              (row) => row.id != excludingId && row.bed.trim() == bed.trim(),
            )
            .firstOrNull;

  @override
  Future<void> saveResident(Resident resident) async {
    final saved = await repository.saveResident(resident);
    if (_disposed) return;
    final index = residents.indexWhere((row) => row.id == resident.id);
    if (index < 0) {
      residents.add(saved);
    } else {
      saved.medicines.addAll(residents[index].medicines);
      residents[index] = saved;
    }
    selectedResidentId = saved.id;
    notifyListeners();
  }

  @override
  Future<void> saveMedicine(String residentId, Medicine medicine) async {
    final saved = await repository.saveMedicine(residentId, medicine);
    if (_disposed) return;
    final list = residents.firstWhere((row) => row.id == residentId).medicines;
    final index = list.indexWhere((row) => row.id == medicine.id);
    if (index < 0) {
      list.add(saved);
    } else {
      list[index] = saved;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

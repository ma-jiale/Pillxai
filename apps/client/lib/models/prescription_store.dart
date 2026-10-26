import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'prescription.dart';
export 'prescription.dart';

/// Public data boundary shared by forms and lists. Execution is a separate owner.
abstract interface class PrescriptionStore implements Listenable {
  List<Resident> get residents;
  String? get selectedResidentId;
  bool get bedtime;
  bool get canEdit;
  void selectResident(String id);
  Resident? bedConflict(String bed, {String? excludingId});
  FutureOr<void> saveResident(Resident resident);
  FutureOr<void> saveMedicine(String residentId, Medicine medicine);
}

String newRecordId() {
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

class SaveFailure implements Exception {
  const SaveFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PrescriptionView {
  /// Returns a new [PrescriptionView] instance.
  PrescriptionView({
    required this.id,
    required this.residentId,
    required this.medicineId,
    required this.revision,
    required this.data,
    required this.updatedAt,
    required this.updatedBy,
  });

  final String id;

  final String residentId;

  final String medicineId;

  final int revision;

  final PrescriptionData data;

  final DateTime updatedAt;

  final String updatedBy;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PrescriptionView &&
    other.id == id &&
    other.residentId == residentId &&
    other.medicineId == medicineId &&
    other.revision == revision &&
    other.data == data &&
    other.updatedAt == updatedAt &&
    other.updatedBy == updatedBy;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (residentId.hashCode) +
    (medicineId.hashCode) +
    (revision.hashCode) +
    (data.hashCode) +
    (updatedAt.hashCode) +
    (updatedBy.hashCode);

  @override
  String toString() => 'PrescriptionView[id=$id, residentId=$residentId, medicineId=$medicineId, revision=$revision, data=$data, updatedAt=$updatedAt, updatedBy=$updatedBy]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'resident_id'] = this.residentId;
      json[r'medicine_id'] = this.medicineId;
      json[r'revision'] = this.revision;
      json[r'data'] = this.data;
      json[r'updated_at'] = this.updatedAt.toUtc().toIso8601String();
      json[r'updated_by'] = this.updatedBy;
    return json;
  }

  /// Clones this instance of [PrescriptionView] and returns a new one where some of the
  /// properties have changed.
  PrescriptionView copyWith({
    String? id,
    String? residentId,
    String? medicineId,
    int? revision,
    PrescriptionData? data,
    DateTime? updatedAt,
    String? updatedBy,
  }) => PrescriptionView(
    id: id ?? this.id,
    residentId: residentId ?? this.residentId,
    medicineId: medicineId ?? this.medicineId,
    revision: revision ?? this.revision,
    data: data ?? this.data,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedBy: updatedBy ?? this.updatedBy,
  );

  /// Returns a new [PrescriptionView] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PrescriptionView? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'), 'Required key "PrescriptionView[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "PrescriptionView[id]" has a null value in JSON.');
        assert(json.containsKey(r'resident_id'), 'Required key "PrescriptionView[resident_id]" is missing from JSON.');
        assert(json[r'resident_id'] != null, 'Required key "PrescriptionView[resident_id]" has a null value in JSON.');
        assert(json.containsKey(r'medicine_id'), 'Required key "PrescriptionView[medicine_id]" is missing from JSON.');
        assert(json[r'medicine_id'] != null, 'Required key "PrescriptionView[medicine_id]" has a null value in JSON.');
        assert(json.containsKey(r'revision'), 'Required key "PrescriptionView[revision]" is missing from JSON.');
        assert(json[r'revision'] != null, 'Required key "PrescriptionView[revision]" has a null value in JSON.');
        assert(json.containsKey(r'data'), 'Required key "PrescriptionView[data]" is missing from JSON.');
        assert(json[r'data'] != null, 'Required key "PrescriptionView[data]" has a null value in JSON.');
        assert(json.containsKey(r'updated_at'), 'Required key "PrescriptionView[updated_at]" is missing from JSON.');
        assert(json[r'updated_at'] != null, 'Required key "PrescriptionView[updated_at]" has a null value in JSON.');
        assert(json.containsKey(r'updated_by'), 'Required key "PrescriptionView[updated_by]" is missing from JSON.');
        assert(json[r'updated_by'] != null, 'Required key "PrescriptionView[updated_by]" has a null value in JSON.');
        return true;
      }());

      return PrescriptionView(
        id: mapValueOfType<String>(json, r'id')!,
        residentId: mapValueOfType<String>(json, r'resident_id')!,
        medicineId: mapValueOfType<String>(json, r'medicine_id')!,
        revision: mapValueOfType<int>(json, r'revision')!,
        data: PrescriptionData.fromJson(json[r'data'])!,
        updatedAt: mapDateTime(json, r'updated_at', r'')!,
        updatedBy: mapValueOfType<String>(json, r'updated_by')!,
      );
    }
    return null;
  }

  static List<PrescriptionView> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PrescriptionView>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PrescriptionView.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PrescriptionView> mapFromJson(dynamic json) {
    final map = <String, PrescriptionView>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PrescriptionView.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PrescriptionView-objects as value to a dart map
  static Map<String, List<PrescriptionView>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PrescriptionView>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PrescriptionView.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'resident_id',
    'medicine_id',
    'revision',
    'data',
    'updated_at',
    'updated_by',
  };
}


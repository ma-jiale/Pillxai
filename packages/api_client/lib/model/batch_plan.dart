//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class BatchPlan {
  /// Returns a new [BatchPlan] instance.
  BatchPlan({
    required this.index,
    required this.tray,
    required this.prescriptionId,
    required this.medicineId,
    required this.name,
    required this.strength,
    required this.feedForm,
    required this.purpose,
    required this.total,
    this.matrix = const [],
    required this.parameters,
  });

  final int index;

  final int tray;

  final String prescriptionId;

  final String medicineId;

  final String name;

  final String strength;

  final String feedForm;

  final String purpose;

  final int total;

  final List<List<int>> matrix;

  final ParameterView parameters;

  @override
  bool operator ==(Object other) => identical(this, other) || other is BatchPlan &&
    other.index == index &&
    other.tray == tray &&
    other.prescriptionId == prescriptionId &&
    other.medicineId == medicineId &&
    other.name == name &&
    other.strength == strength &&
    other.feedForm == feedForm &&
    other.purpose == purpose &&
    other.total == total &&
    _deepEquality.equals(other.matrix, matrix) &&
    other.parameters == parameters;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (index.hashCode) +
    (tray.hashCode) +
    (prescriptionId.hashCode) +
    (medicineId.hashCode) +
    (name.hashCode) +
    (strength.hashCode) +
    (feedForm.hashCode) +
    (purpose.hashCode) +
    (total.hashCode) +
    (matrix.hashCode) +
    (parameters.hashCode);

  @override
  String toString() => 'BatchPlan[index=$index, tray=$tray, prescriptionId=$prescriptionId, medicineId=$medicineId, name=$name, strength=$strength, feedForm=$feedForm, purpose=$purpose, total=$total, matrix=$matrix, parameters=$parameters]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'index'] = this.index;
      json[r'tray'] = this.tray;
      json[r'prescription_id'] = this.prescriptionId;
      json[r'medicine_id'] = this.medicineId;
      json[r'name'] = this.name;
      json[r'strength'] = this.strength;
      json[r'feed_form'] = this.feedForm;
      json[r'purpose'] = this.purpose;
      json[r'total'] = this.total;
      json[r'matrix'] = this.matrix;
      json[r'parameters'] = this.parameters;
    return json;
  }

  /// Clones this instance of [BatchPlan] and returns a new one where some of the
  /// properties have changed.
  BatchPlan copyWith({
    int? index,
    int? tray,
    String? prescriptionId,
    String? medicineId,
    String? name,
    String? strength,
    String? feedForm,
    String? purpose,
    int? total,
    List<List<int>>? matrix,
    ParameterView? parameters,
  }) => BatchPlan(
    index: index ?? this.index,
    tray: tray ?? this.tray,
    prescriptionId: prescriptionId ?? this.prescriptionId,
    medicineId: medicineId ?? this.medicineId,
    name: name ?? this.name,
    strength: strength ?? this.strength,
    feedForm: feedForm ?? this.feedForm,
    purpose: purpose ?? this.purpose,
    total: total ?? this.total,
    matrix: matrix ?? this.matrix,
    parameters: parameters ?? this.parameters,
  );

  /// Returns a new [BatchPlan] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static BatchPlan? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'index'), 'Required key "BatchPlan[index]" is missing from JSON.');
        assert(json[r'index'] != null, 'Required key "BatchPlan[index]" has a null value in JSON.');
        assert(json.containsKey(r'tray'), 'Required key "BatchPlan[tray]" is missing from JSON.');
        assert(json[r'tray'] != null, 'Required key "BatchPlan[tray]" has a null value in JSON.');
        assert(json.containsKey(r'prescription_id'), 'Required key "BatchPlan[prescription_id]" is missing from JSON.');
        assert(json[r'prescription_id'] != null, 'Required key "BatchPlan[prescription_id]" has a null value in JSON.');
        assert(json.containsKey(r'medicine_id'), 'Required key "BatchPlan[medicine_id]" is missing from JSON.');
        assert(json[r'medicine_id'] != null, 'Required key "BatchPlan[medicine_id]" has a null value in JSON.');
        assert(json.containsKey(r'name'), 'Required key "BatchPlan[name]" is missing from JSON.');
        assert(json[r'name'] != null, 'Required key "BatchPlan[name]" has a null value in JSON.');
        assert(json.containsKey(r'strength'), 'Required key "BatchPlan[strength]" is missing from JSON.');
        assert(json[r'strength'] != null, 'Required key "BatchPlan[strength]" has a null value in JSON.');
        assert(json.containsKey(r'feed_form'), 'Required key "BatchPlan[feed_form]" is missing from JSON.');
        assert(json[r'feed_form'] != null, 'Required key "BatchPlan[feed_form]" has a null value in JSON.');
        assert(json.containsKey(r'purpose'), 'Required key "BatchPlan[purpose]" is missing from JSON.');
        assert(json[r'purpose'] != null, 'Required key "BatchPlan[purpose]" has a null value in JSON.');
        assert(json.containsKey(r'total'), 'Required key "BatchPlan[total]" is missing from JSON.');
        assert(json[r'total'] != null, 'Required key "BatchPlan[total]" has a null value in JSON.');
        assert(json.containsKey(r'matrix'), 'Required key "BatchPlan[matrix]" is missing from JSON.');
        assert(json[r'matrix'] != null, 'Required key "BatchPlan[matrix]" has a null value in JSON.');
        assert(json.containsKey(r'parameters'), 'Required key "BatchPlan[parameters]" is missing from JSON.');
        assert(json[r'parameters'] != null, 'Required key "BatchPlan[parameters]" has a null value in JSON.');
        return true;
      }());

      return BatchPlan(
        index: mapValueOfType<int>(json, r'index')!,
        tray: mapValueOfType<int>(json, r'tray')!,
        prescriptionId: mapValueOfType<String>(json, r'prescription_id')!,
        medicineId: mapValueOfType<String>(json, r'medicine_id')!,
        name: mapValueOfType<String>(json, r'name')!,
        strength: mapValueOfType<String>(json, r'strength')!,
        feedForm: mapValueOfType<String>(json, r'feed_form')!,
        purpose: mapValueOfType<String>(json, r'purpose')!,
        total: mapValueOfType<int>(json, r'total')!,
        matrix: json[r'matrix'] is List
          ? (json[r'matrix'] as List).map((e) =>
              e == null ? const <int>[] : (e as List).map((value) => value as int).toList(growable: false)
            ).toList()
          :  const [],
        parameters: ParameterView.fromJson(json[r'parameters'])!,
      );
    }
    return null;
  }

  static List<BatchPlan> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <BatchPlan>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = BatchPlan.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, BatchPlan> mapFromJson(dynamic json) {
    final map = <String, BatchPlan>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = BatchPlan.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of BatchPlan-objects as value to a dart map
  static Map<String, List<BatchPlan>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<BatchPlan>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = BatchPlan.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'index',
    'tray',
    'prescription_id',
    'medicine_id',
    'name',
    'strength',
    'feed_form',
    'purpose',
    'total',
    'matrix',
    'parameters',
  };
}


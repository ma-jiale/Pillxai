//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ParameterView {
  /// Returns a new [ParameterView] instance.
  ParameterView({
    required this.prescriptionId,
    required this.medicineId,
    required this.revision,
    required this.turntable,
    required this.gate,
    this.simulationOnly = false,
  });

  final String prescriptionId;

  final String medicineId;

  final int revision;

  final num turntable;

  final num gate;

  final bool simulationOnly;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ParameterView &&
    other.prescriptionId == prescriptionId &&
    other.medicineId == medicineId &&
    other.revision == revision &&
    other.turntable == turntable &&
    other.gate == gate &&
    other.simulationOnly == simulationOnly;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (prescriptionId.hashCode) +
    (medicineId.hashCode) +
    (revision.hashCode) +
    (turntable.hashCode) +
    (gate.hashCode) +
    (simulationOnly.hashCode);

  @override
  String toString() => 'ParameterView[prescriptionId=$prescriptionId, medicineId=$medicineId, revision=$revision, turntable=$turntable, gate=$gate, simulationOnly=$simulationOnly]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'prescription_id'] = this.prescriptionId;
      json[r'medicine_id'] = this.medicineId;
      json[r'revision'] = this.revision;
      json[r'turntable'] = this.turntable;
      json[r'gate'] = this.gate;
      json[r'simulation_only'] = this.simulationOnly;
    return json;
  }

  /// Clones this instance of [ParameterView] and returns a new one where some of the
  /// properties have changed.
  ParameterView copyWith({
    String? prescriptionId,
    String? medicineId,
    int? revision,
    num? turntable,
    num? gate,
    bool? simulationOnly,
  }) => ParameterView(
    prescriptionId: prescriptionId ?? this.prescriptionId,
    medicineId: medicineId ?? this.medicineId,
    revision: revision ?? this.revision,
    turntable: turntable ?? this.turntable,
    gate: gate ?? this.gate,
    simulationOnly: simulationOnly ?? this.simulationOnly,
  );

  /// Returns a new [ParameterView] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ParameterView? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'prescription_id'), 'Required key "ParameterView[prescription_id]" is missing from JSON.');
        assert(json[r'prescription_id'] != null, 'Required key "ParameterView[prescription_id]" has a null value in JSON.');
        assert(json.containsKey(r'medicine_id'), 'Required key "ParameterView[medicine_id]" is missing from JSON.');
        assert(json[r'medicine_id'] != null, 'Required key "ParameterView[medicine_id]" has a null value in JSON.');
        assert(json.containsKey(r'revision'), 'Required key "ParameterView[revision]" is missing from JSON.');
        assert(json[r'revision'] != null, 'Required key "ParameterView[revision]" has a null value in JSON.');
        assert(json.containsKey(r'turntable'), 'Required key "ParameterView[turntable]" is missing from JSON.');
        assert(json[r'turntable'] != null, 'Required key "ParameterView[turntable]" has a null value in JSON.');
        assert(json.containsKey(r'gate'), 'Required key "ParameterView[gate]" is missing from JSON.');
        assert(json[r'gate'] != null, 'Required key "ParameterView[gate]" has a null value in JSON.');
        return true;
      }());

      return ParameterView(
        prescriptionId: mapValueOfType<String>(json, r'prescription_id')!,
        medicineId: mapValueOfType<String>(json, r'medicine_id')!,
        revision: mapValueOfType<int>(json, r'revision')!,
        turntable: num.parse('${json[r'turntable']}'),
        gate: num.parse('${json[r'gate']}'),
        simulationOnly: mapValueOfType<bool>(json, r'simulation_only') ?? false,
      );
    }
    return null;
  }

  static List<ParameterView> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ParameterView>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ParameterView.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ParameterView> mapFromJson(dynamic json) {
    final map = <String, ParameterView>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ParameterView.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ParameterView-objects as value to a dart map
  static Map<String, List<ParameterView>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ParameterView>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ParameterView.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'prescription_id',
    'medicine_id',
    'revision',
    'turntable',
    'gate',
  };
}


//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class MedicationParameters {
  /// Returns a new [MedicationParameters] instance.
  MedicationParameters({
    required this.expectedRevision,
    required this.medicineId,
    required this.turntable,
    required this.gate,
    this.simulationOnly = false,
    this.learningEnabled = true,
    this.hasValues = true,
  });

  /// Minimum value: 0
  final int expectedRevision;

  final String medicineId;

  /// Minimum value: 0.0
  final num turntable;

  /// Minimum value: 0.0
  /// Maximum value: 1.0
  final num gate;

  final bool simulationOnly;

  final bool learningEnabled;

  final bool hasValues;

  @override
  bool operator ==(Object other) => identical(this, other) || other is MedicationParameters &&
    other.expectedRevision == expectedRevision &&
    other.medicineId == medicineId &&
    other.turntable == turntable &&
    other.gate == gate &&
    other.simulationOnly == simulationOnly &&
    other.learningEnabled == learningEnabled &&
    other.hasValues == hasValues;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (expectedRevision.hashCode) +
    (medicineId.hashCode) +
    (turntable.hashCode) +
    (gate.hashCode) +
    (simulationOnly.hashCode) +
    (learningEnabled.hashCode) +
    (hasValues.hashCode);

  @override
  String toString() => 'MedicationParameters[expectedRevision=$expectedRevision, medicineId=$medicineId, turntable=$turntable, gate=$gate, simulationOnly=$simulationOnly, learningEnabled=$learningEnabled, hasValues=$hasValues]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'expected_revision'] = this.expectedRevision;
      json[r'medicine_id'] = this.medicineId;
      json[r'turntable'] = this.turntable;
      json[r'gate'] = this.gate;
      json[r'simulation_only'] = this.simulationOnly;
      json[r'learning_enabled'] = this.learningEnabled;
      json[r'has_values'] = this.hasValues;
    return json;
  }

  /// Clones this instance of [MedicationParameters] and returns a new one where some of the
  /// properties have changed.
  MedicationParameters copyWith({
    int? expectedRevision,
    String? medicineId,
    num? turntable,
    num? gate,
    bool? simulationOnly,
    bool? learningEnabled,
    bool? hasValues,
  }) => MedicationParameters(
    expectedRevision: expectedRevision ?? this.expectedRevision,
    medicineId: medicineId ?? this.medicineId,
    turntable: turntable ?? this.turntable,
    gate: gate ?? this.gate,
    simulationOnly: simulationOnly ?? this.simulationOnly,
    learningEnabled: learningEnabled ?? this.learningEnabled,
    hasValues: hasValues ?? this.hasValues,
  );

  /// Returns a new [MedicationParameters] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static MedicationParameters? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'expected_revision'), 'Required key "MedicationParameters[expected_revision]" is missing from JSON.');
        assert(json[r'expected_revision'] != null, 'Required key "MedicationParameters[expected_revision]" has a null value in JSON.');
        assert(json.containsKey(r'medicine_id'), 'Required key "MedicationParameters[medicine_id]" is missing from JSON.');
        assert(json[r'medicine_id'] != null, 'Required key "MedicationParameters[medicine_id]" has a null value in JSON.');
        assert(json.containsKey(r'turntable'), 'Required key "MedicationParameters[turntable]" is missing from JSON.');
        assert(json[r'turntable'] != null, 'Required key "MedicationParameters[turntable]" has a null value in JSON.');
        assert(json.containsKey(r'gate'), 'Required key "MedicationParameters[gate]" is missing from JSON.');
        assert(json[r'gate'] != null, 'Required key "MedicationParameters[gate]" has a null value in JSON.');
        return true;
      }());

      return MedicationParameters(
        expectedRevision: mapValueOfType<int>(json, r'expected_revision')!,
        medicineId: mapValueOfType<String>(json, r'medicine_id')!,
        turntable: num.parse('${json[r'turntable']}'),
        gate: num.parse('${json[r'gate']}'),
        simulationOnly: mapValueOfType<bool>(json, r'simulation_only') ?? false,
        learningEnabled: mapValueOfType<bool>(json, r'learning_enabled') ?? true,
        hasValues: mapValueOfType<bool>(json, r'has_values') ?? true,
      );
    }
    return null;
  }

  static List<MedicationParameters> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <MedicationParameters>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MedicationParameters.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, MedicationParameters> mapFromJson(dynamic json) {
    final map = <String, MedicationParameters>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = MedicationParameters.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of MedicationParameters-objects as value to a dart map
  static Map<String, List<MedicationParameters>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<MedicationParameters>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = MedicationParameters.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'expected_revision',
    'medicine_id',
    'turntable',
    'gate',
  };
}


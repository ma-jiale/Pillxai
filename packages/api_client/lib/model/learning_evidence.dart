//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class LearningEvidence {
  /// Returns a new [LearningEvidence] instance.
  LearningEvidence({
    required this.initialGate,
    required this.hadValidHistory,
    this.manualGate,
    this.samples = const [],
    this.adjustments = const [],
    required this.validSamples,
  });

  final num initialGate;

  final bool hadValidHistory;

  final num? manualGate;

  final List<LearningSample> samples;

  final List<LearningAdjustment> adjustments;

  final int validSamples;

  @override
  bool operator ==(Object other) => identical(this, other) || other is LearningEvidence &&
    other.initialGate == initialGate &&
    other.hadValidHistory == hadValidHistory &&
    other.manualGate == manualGate &&
    _deepEquality.equals(other.samples, samples) &&
    _deepEquality.equals(other.adjustments, adjustments) &&
    other.validSamples == validSamples;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (initialGate.hashCode) +
    (hadValidHistory.hashCode) +
    (manualGate == null ? 0 : manualGate!.hashCode) +
    (samples.hashCode) +
    (adjustments.hashCode) +
    (validSamples.hashCode);

  @override
  String toString() => 'LearningEvidence[initialGate=$initialGate, hadValidHistory=$hadValidHistory, manualGate=$manualGate, samples=$samples, adjustments=$adjustments, validSamples=$validSamples]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'initial_gate'] = this.initialGate;
      json[r'had_valid_history'] = this.hadValidHistory;
    if (this.manualGate != null) {
      json[r'manual_gate'] = this.manualGate;
    } else {
      json[r'manual_gate'] = null;
    }
      json[r'samples'] = this.samples;
      json[r'adjustments'] = this.adjustments;
      json[r'valid_samples'] = this.validSamples;
    return json;
  }

  /// Clones this instance of [LearningEvidence] and returns a new one where some of the
  /// properties have changed.
  LearningEvidence copyWith({
    num? initialGate,
    bool? hadValidHistory,
    num? manualGate,
    bool manualGateSetToNull = false,
    List<LearningSample>? samples,
    List<LearningAdjustment>? adjustments,
    int? validSamples,
  }) => LearningEvidence(
    initialGate: initialGate ?? this.initialGate,
    hadValidHistory: hadValidHistory ?? this.hadValidHistory,
    manualGate: manualGateSetToNull ? null : manualGate ?? this.manualGate,
    samples: samples ?? this.samples,
    adjustments: adjustments ?? this.adjustments,
    validSamples: validSamples ?? this.validSamples,
  );

  /// Returns a new [LearningEvidence] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static LearningEvidence? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'initial_gate'), 'Required key "LearningEvidence[initial_gate]" is missing from JSON.');
        assert(json[r'initial_gate'] != null, 'Required key "LearningEvidence[initial_gate]" has a null value in JSON.');
        assert(json.containsKey(r'had_valid_history'), 'Required key "LearningEvidence[had_valid_history]" is missing from JSON.');
        assert(json[r'had_valid_history'] != null, 'Required key "LearningEvidence[had_valid_history]" has a null value in JSON.');
        assert(json.containsKey(r'valid_samples'), 'Required key "LearningEvidence[valid_samples]" is missing from JSON.');
        assert(json[r'valid_samples'] != null, 'Required key "LearningEvidence[valid_samples]" has a null value in JSON.');
        return true;
      }());

      return LearningEvidence(
        initialGate: num.parse('${json[r'initial_gate']}'),
        hadValidHistory: mapValueOfType<bool>(json, r'had_valid_history')!,
        manualGate: json[r'manual_gate'] == null
            ? null
            : num.parse('${json[r'manual_gate']}'),
        samples: LearningSample.listFromJson(json[r'samples']),
        adjustments: LearningAdjustment.listFromJson(json[r'adjustments']),
        validSamples: mapValueOfType<int>(json, r'valid_samples')!,
      );
    }
    return null;
  }

  static List<LearningEvidence> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <LearningEvidence>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = LearningEvidence.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, LearningEvidence> mapFromJson(dynamic json) {
    final map = <String, LearningEvidence>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = LearningEvidence.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of LearningEvidence-objects as value to a dart map
  static Map<String, List<LearningEvidence>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<LearningEvidence>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = LearningEvidence.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'initial_gate',
    'had_valid_history',
    'valid_samples',
  };
}


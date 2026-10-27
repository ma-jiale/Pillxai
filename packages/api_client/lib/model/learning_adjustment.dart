//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class LearningAdjustment {
  /// Returns a new [LearningAdjustment] instance.
  LearningAdjustment({
    required this.sequence,
    this.value,
    required this.appliedToLearning,
  });

  final int sequence;

  final num? value;

  final bool appliedToLearning;

  @override
  bool operator ==(Object other) => identical(this, other) || other is LearningAdjustment &&
    other.sequence == sequence &&
    other.value == value &&
    other.appliedToLearning == appliedToLearning;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (sequence.hashCode) +
    (value == null ? 0 : value!.hashCode) +
    (appliedToLearning.hashCode);

  @override
  String toString() => 'LearningAdjustment[sequence=$sequence, value=$value, appliedToLearning=$appliedToLearning]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'sequence'] = this.sequence;
    if (this.value != null) {
      json[r'value'] = this.value;
    } else {
      json[r'value'] = null;
    }
      json[r'applied_to_learning'] = this.appliedToLearning;
    return json;
  }

  /// Clones this instance of [LearningAdjustment] and returns a new one where some of the
  /// properties have changed.
  LearningAdjustment copyWith({
    int? sequence,
    num? value,
    bool valueSetToNull = false,
    bool? appliedToLearning,
  }) => LearningAdjustment(
    sequence: sequence ?? this.sequence,
    value: valueSetToNull ? null : value ?? this.value,
    appliedToLearning: appliedToLearning ?? this.appliedToLearning,
  );

  /// Returns a new [LearningAdjustment] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static LearningAdjustment? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'sequence'), 'Required key "LearningAdjustment[sequence]" is missing from JSON.');
        assert(json[r'sequence'] != null, 'Required key "LearningAdjustment[sequence]" has a null value in JSON.');
        assert(json.containsKey(r'applied_to_learning'), 'Required key "LearningAdjustment[applied_to_learning]" is missing from JSON.');
        assert(json[r'applied_to_learning'] != null, 'Required key "LearningAdjustment[applied_to_learning]" has a null value in JSON.');
        return true;
      }());

      return LearningAdjustment(
        sequence: mapValueOfType<int>(json, r'sequence')!,
        value: json[r'value'] == null
            ? null
            : num.parse('${json[r'value']}'),
        appliedToLearning: mapValueOfType<bool>(json, r'applied_to_learning')!,
      );
    }
    return null;
  }

  static List<LearningAdjustment> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <LearningAdjustment>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = LearningAdjustment.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, LearningAdjustment> mapFromJson(dynamic json) {
    final map = <String, LearningAdjustment>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = LearningAdjustment.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of LearningAdjustment-objects as value to a dart map
  static Map<String, List<LearningAdjustment>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<LearningAdjustment>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = LearningAdjustment.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'sequence',
    'applied_to_learning',
  };
}


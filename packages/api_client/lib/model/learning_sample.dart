//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class LearningSample {
  /// Returns a new [LearningSample] instance.
  LearningSample({
    required this.sequence,
    this.number,
    this.rawWidth,
    required this.reason,
  });

  final int sequence;

  final int? number;

  final String? rawWidth;

  final String reason;

  @override
  bool operator ==(Object other) => identical(this, other) || other is LearningSample &&
    other.sequence == sequence &&
    other.number == number &&
    other.rawWidth == rawWidth &&
    other.reason == reason;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (sequence.hashCode) +
    (number == null ? 0 : number!.hashCode) +
    (rawWidth == null ? 0 : rawWidth!.hashCode) +
    (reason.hashCode);

  @override
  String toString() => 'LearningSample[sequence=$sequence, number=$number, rawWidth=$rawWidth, reason=$reason]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'sequence'] = this.sequence;
    if (this.number != null) {
      json[r'number'] = this.number;
    } else {
      json[r'number'] = null;
    }
    if (this.rawWidth != null) {
      json[r'raw_width'] = this.rawWidth;
    } else {
      json[r'raw_width'] = null;
    }
      json[r'reason'] = this.reason;
    return json;
  }

  /// Clones this instance of [LearningSample] and returns a new one where some of the
  /// properties have changed.
  LearningSample copyWith({
    int? sequence,
    int? number,
    bool numberSetToNull = false,
    String? rawWidth,
    bool rawWidthSetToNull = false,
    String? reason,
  }) => LearningSample(
    sequence: sequence ?? this.sequence,
    number: numberSetToNull ? null : number ?? this.number,
    rawWidth: rawWidthSetToNull ? null : rawWidth ?? this.rawWidth,
    reason: reason ?? this.reason,
  );

  /// Returns a new [LearningSample] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static LearningSample? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'sequence'), 'Required key "LearningSample[sequence]" is missing from JSON.');
        assert(json[r'sequence'] != null, 'Required key "LearningSample[sequence]" has a null value in JSON.');
        assert(json.containsKey(r'reason'), 'Required key "LearningSample[reason]" is missing from JSON.');
        assert(json[r'reason'] != null, 'Required key "LearningSample[reason]" has a null value in JSON.');
        return true;
      }());

      return LearningSample(
        sequence: mapValueOfType<int>(json, r'sequence')!,
        number: mapValueOfType<int>(json, r'number'),
        rawWidth: mapValueOfType<String>(json, r'raw_width'),
        reason: mapValueOfType<String>(json, r'reason')!,
      );
    }
    return null;
  }

  static List<LearningSample> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <LearningSample>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = LearningSample.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, LearningSample> mapFromJson(dynamic json) {
    final map = <String, LearningSample>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = LearningSample.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of LearningSample-objects as value to a dart map
  static Map<String, List<LearningSample>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<LearningSample>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = LearningSample.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'sequence',
    'reason',
  };
}


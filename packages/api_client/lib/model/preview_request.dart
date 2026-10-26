//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PreviewRequest {
  /// Returns a new [PreviewRequest] instance.
  PreviewRequest({
    this.days,
    this.splitMeals,
  });

  /// Minimum value: 1
  /// Maximum value: 7
  final int? days;

  final bool? splitMeals;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PreviewRequest &&
    other.days == days &&
    other.splitMeals == splitMeals;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (days == null ? 0 : days!.hashCode) +
    (splitMeals == null ? 0 : splitMeals!.hashCode);

  @override
  String toString() => 'PreviewRequest[days=$days, splitMeals=$splitMeals]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.days != null) {
      json[r'days'] = this.days;
    } else {
      json[r'days'] = null;
    }
    if (this.splitMeals != null) {
      json[r'split_meals'] = this.splitMeals;
    } else {
      json[r'split_meals'] = null;
    }
    return json;
  }

  /// Clones this instance of [PreviewRequest] and returns a new one where some of the
  /// properties have changed.
  PreviewRequest copyWith({
    int? days,
    bool daysSetToNull = false,
    bool? splitMeals,
    bool splitMealsSetToNull = false,
  }) => PreviewRequest(
    days: daysSetToNull ? null : days ?? this.days,
    splitMeals: splitMealsSetToNull ? null : splitMeals ?? this.splitMeals,
  );

  /// Returns a new [PreviewRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PreviewRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        return true;
      }());

      return PreviewRequest(
        days: mapValueOfType<int>(json, r'days'),
        splitMeals: mapValueOfType<bool>(json, r'split_meals'),
      );
    }
    return null;
  }

  static List<PreviewRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PreviewRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PreviewRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PreviewRequest> mapFromJson(dynamic json) {
    final map = <String, PreviewRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PreviewRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PreviewRequest-objects as value to a dart map
  static Map<String, List<PreviewRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PreviewRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PreviewRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}


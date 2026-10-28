//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SaveSettings {
  /// Returns a new [SaveSettings] instance.
  SaveSettings({
    required this.expectedRevision,
    required this.preparationDays,
    required this.splitMeals,
    required this.bedtimeEnabled,
    required this.startTomorrow,
  });

  /// Minimum value: 1
  final int expectedRevision;

  /// Minimum value: 1
  /// Maximum value: 7
  final int preparationDays;

  final bool splitMeals;

  final bool bedtimeEnabled;

  final bool startTomorrow;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SaveSettings &&
    other.expectedRevision == expectedRevision &&
    other.preparationDays == preparationDays &&
    other.splitMeals == splitMeals &&
    other.bedtimeEnabled == bedtimeEnabled &&
    other.startTomorrow == startTomorrow;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (expectedRevision.hashCode) +
    (preparationDays.hashCode) +
    (splitMeals.hashCode) +
    (bedtimeEnabled.hashCode) +
    (startTomorrow.hashCode);

  @override
  String toString() => 'SaveSettings[expectedRevision=$expectedRevision, preparationDays=$preparationDays, splitMeals=$splitMeals, bedtimeEnabled=$bedtimeEnabled, startTomorrow=$startTomorrow]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'expected_revision'] = this.expectedRevision;
      json[r'preparation_days'] = this.preparationDays;
      json[r'split_meals'] = this.splitMeals;
      json[r'bedtime_enabled'] = this.bedtimeEnabled;
      json[r'start_tomorrow'] = this.startTomorrow;
    return json;
  }

  /// Clones this instance of [SaveSettings] and returns a new one where some of the
  /// properties have changed.
  SaveSettings copyWith({
    int? expectedRevision,
    int? preparationDays,
    bool? splitMeals,
    bool? bedtimeEnabled,
    bool? startTomorrow,
  }) => SaveSettings(
    expectedRevision: expectedRevision ?? this.expectedRevision,
    preparationDays: preparationDays ?? this.preparationDays,
    splitMeals: splitMeals ?? this.splitMeals,
    bedtimeEnabled: bedtimeEnabled ?? this.bedtimeEnabled,
    startTomorrow: startTomorrow ?? this.startTomorrow,
  );

  /// Returns a new [SaveSettings] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SaveSettings? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'expected_revision'), 'Required key "SaveSettings[expected_revision]" is missing from JSON.');
        assert(json[r'expected_revision'] != null, 'Required key "SaveSettings[expected_revision]" has a null value in JSON.');
        assert(json.containsKey(r'preparation_days'), 'Required key "SaveSettings[preparation_days]" is missing from JSON.');
        assert(json[r'preparation_days'] != null, 'Required key "SaveSettings[preparation_days]" has a null value in JSON.');
        assert(json.containsKey(r'split_meals'), 'Required key "SaveSettings[split_meals]" is missing from JSON.');
        assert(json[r'split_meals'] != null, 'Required key "SaveSettings[split_meals]" has a null value in JSON.');
        assert(json.containsKey(r'bedtime_enabled'), 'Required key "SaveSettings[bedtime_enabled]" is missing from JSON.');
        assert(json[r'bedtime_enabled'] != null, 'Required key "SaveSettings[bedtime_enabled]" has a null value in JSON.');
        assert(json.containsKey(r'start_tomorrow'), 'Required key "SaveSettings[start_tomorrow]" is missing from JSON.');
        assert(json[r'start_tomorrow'] != null, 'Required key "SaveSettings[start_tomorrow]" has a null value in JSON.');
        return true;
      }());

      return SaveSettings(
        expectedRevision: mapValueOfType<int>(json, r'expected_revision')!,
        preparationDays: mapValueOfType<int>(json, r'preparation_days')!,
        splitMeals: mapValueOfType<bool>(json, r'split_meals')!,
        bedtimeEnabled: mapValueOfType<bool>(json, r'bedtime_enabled')!,
        startTomorrow: mapValueOfType<bool>(json, r'start_tomorrow')!,
      );
    }
    return null;
  }

  static List<SaveSettings> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SaveSettings>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SaveSettings.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SaveSettings> mapFromJson(dynamic json) {
    final map = <String, SaveSettings>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SaveSettings.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SaveSettings-objects as value to a dart map
  static Map<String, List<SaveSettings>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SaveSettings>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SaveSettings.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'expected_revision',
    'preparation_days',
    'split_meals',
    'bedtime_enabled',
    'start_tomorrow',
  };
}


//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AppSettings {
  /// Returns a new [AppSettings] instance.
  AppSettings({
    required this.timezone,
    required this.bedtimeEnabled,
    required this.preparationDays,
    required this.splitMeals,
    required this.startTomorrow,
    required this.revision,
  });

  final String timezone;

  final bool bedtimeEnabled;

  final int preparationDays;

  final bool splitMeals;

  final bool startTomorrow;

  final int revision;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AppSettings &&
    other.timezone == timezone &&
    other.bedtimeEnabled == bedtimeEnabled &&
    other.preparationDays == preparationDays &&
    other.splitMeals == splitMeals &&
    other.startTomorrow == startTomorrow &&
    other.revision == revision;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (timezone.hashCode) +
    (bedtimeEnabled.hashCode) +
    (preparationDays.hashCode) +
    (splitMeals.hashCode) +
    (startTomorrow.hashCode) +
    (revision.hashCode);

  @override
  String toString() => 'AppSettings[timezone=$timezone, bedtimeEnabled=$bedtimeEnabled, preparationDays=$preparationDays, splitMeals=$splitMeals, startTomorrow=$startTomorrow, revision=$revision]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'timezone'] = this.timezone;
      json[r'bedtime_enabled'] = this.bedtimeEnabled;
      json[r'preparation_days'] = this.preparationDays;
      json[r'split_meals'] = this.splitMeals;
      json[r'start_tomorrow'] = this.startTomorrow;
      json[r'revision'] = this.revision;
    return json;
  }

  /// Clones this instance of [AppSettings] and returns a new one where some of the
  /// properties have changed.
  AppSettings copyWith({
    String? timezone,
    bool? bedtimeEnabled,
    int? preparationDays,
    bool? splitMeals,
    bool? startTomorrow,
    int? revision,
  }) => AppSettings(
    timezone: timezone ?? this.timezone,
    bedtimeEnabled: bedtimeEnabled ?? this.bedtimeEnabled,
    preparationDays: preparationDays ?? this.preparationDays,
    splitMeals: splitMeals ?? this.splitMeals,
    startTomorrow: startTomorrow ?? this.startTomorrow,
    revision: revision ?? this.revision,
  );

  /// Returns a new [AppSettings] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AppSettings? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'timezone'), 'Required key "AppSettings[timezone]" is missing from JSON.');
        assert(json[r'timezone'] != null, 'Required key "AppSettings[timezone]" has a null value in JSON.');
        assert(json.containsKey(r'bedtime_enabled'), 'Required key "AppSettings[bedtime_enabled]" is missing from JSON.');
        assert(json[r'bedtime_enabled'] != null, 'Required key "AppSettings[bedtime_enabled]" has a null value in JSON.');
        assert(json.containsKey(r'preparation_days'), 'Required key "AppSettings[preparation_days]" is missing from JSON.');
        assert(json[r'preparation_days'] != null, 'Required key "AppSettings[preparation_days]" has a null value in JSON.');
        assert(json.containsKey(r'split_meals'), 'Required key "AppSettings[split_meals]" is missing from JSON.');
        assert(json[r'split_meals'] != null, 'Required key "AppSettings[split_meals]" has a null value in JSON.');
        assert(json.containsKey(r'start_tomorrow'), 'Required key "AppSettings[start_tomorrow]" is missing from JSON.');
        assert(json[r'start_tomorrow'] != null, 'Required key "AppSettings[start_tomorrow]" has a null value in JSON.');
        assert(json.containsKey(r'revision'), 'Required key "AppSettings[revision]" is missing from JSON.');
        assert(json[r'revision'] != null, 'Required key "AppSettings[revision]" has a null value in JSON.');
        return true;
      }());

      return AppSettings(
        timezone: mapValueOfType<String>(json, r'timezone')!,
        bedtimeEnabled: mapValueOfType<bool>(json, r'bedtime_enabled')!,
        preparationDays: mapValueOfType<int>(json, r'preparation_days')!,
        splitMeals: mapValueOfType<bool>(json, r'split_meals')!,
        startTomorrow: mapValueOfType<bool>(json, r'start_tomorrow')!,
        revision: mapValueOfType<int>(json, r'revision')!,
      );
    }
    return null;
  }

  static List<AppSettings> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AppSettings>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AppSettings.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AppSettings> mapFromJson(dynamic json) {
    final map = <String, AppSettings>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AppSettings.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AppSettings-objects as value to a dart map
  static Map<String, List<AppSettings>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AppSettings>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AppSettings.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'timezone',
    'bedtime_enabled',
    'preparation_days',
    'split_meals',
    'start_tomorrow',
    'revision',
  };
}


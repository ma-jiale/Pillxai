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
  });

  final String timezone;

  final bool bedtimeEnabled;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AppSettings &&
    other.timezone == timezone &&
    other.bedtimeEnabled == bedtimeEnabled;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (timezone.hashCode) +
    (bedtimeEnabled.hashCode);

  @override
  String toString() => 'AppSettings[timezone=$timezone, bedtimeEnabled=$bedtimeEnabled]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'timezone'] = this.timezone;
      json[r'bedtime_enabled'] = this.bedtimeEnabled;
    return json;
  }

  /// Clones this instance of [AppSettings] and returns a new one where some of the
  /// properties have changed.
  AppSettings copyWith({
    String? timezone,
    bool? bedtimeEnabled,
  }) => AppSettings(
    timezone: timezone ?? this.timezone,
    bedtimeEnabled: bedtimeEnabled ?? this.bedtimeEnabled,
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
        return true;
      }());

      return AppSettings(
        timezone: mapValueOfType<String>(json, r'timezone')!,
        bedtimeEnabled: mapValueOfType<bool>(json, r'bedtime_enabled')!,
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
  };
}


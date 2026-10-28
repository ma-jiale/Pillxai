//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SaveDevice {
  /// Returns a new [SaveDevice] instance.
  SaveDevice({
    required this.expectedRevision,
    required this.configuration,
  });

  /// Minimum value: 0
  final int expectedRevision;

  final DeviceConfiguration configuration;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SaveDevice &&
    other.expectedRevision == expectedRevision &&
    other.configuration == configuration;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (expectedRevision.hashCode) +
    (configuration.hashCode);

  @override
  String toString() => 'SaveDevice[expectedRevision=$expectedRevision, configuration=$configuration]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'expected_revision'] = this.expectedRevision;
      json[r'configuration'] = this.configuration;
    return json;
  }

  /// Clones this instance of [SaveDevice] and returns a new one where some of the
  /// properties have changed.
  SaveDevice copyWith({
    int? expectedRevision,
    DeviceConfiguration? configuration,
  }) => SaveDevice(
    expectedRevision: expectedRevision ?? this.expectedRevision,
    configuration: configuration ?? this.configuration,
  );

  /// Returns a new [SaveDevice] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SaveDevice? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'expected_revision'), 'Required key "SaveDevice[expected_revision]" is missing from JSON.');
        assert(json[r'expected_revision'] != null, 'Required key "SaveDevice[expected_revision]" has a null value in JSON.');
        assert(json.containsKey(r'configuration'), 'Required key "SaveDevice[configuration]" is missing from JSON.');
        assert(json[r'configuration'] != null, 'Required key "SaveDevice[configuration]" has a null value in JSON.');
        return true;
      }());

      return SaveDevice(
        expectedRevision: mapValueOfType<int>(json, r'expected_revision')!,
        configuration: DeviceConfiguration.fromJson(json[r'configuration'])!,
      );
    }
    return null;
  }

  static List<SaveDevice> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SaveDevice>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SaveDevice.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SaveDevice> mapFromJson(dynamic json) {
    final map = <String, SaveDevice>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SaveDevice.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SaveDevice-objects as value to a dart map
  static Map<String, List<SaveDevice>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SaveDevice>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SaveDevice.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'expected_revision',
    'configuration',
  };
}


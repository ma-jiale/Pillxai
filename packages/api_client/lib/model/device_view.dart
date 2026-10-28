//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class DeviceView {
  /// Returns a new [DeviceView] instance.
  DeviceView({
    required this.id,
    required this.revision,
    required this.configuration,
  });

  final String id;

  final int revision;

  final DeviceConfiguration configuration;

  @override
  bool operator ==(Object other) => identical(this, other) || other is DeviceView &&
    other.id == id &&
    other.revision == revision &&
    other.configuration == configuration;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (revision.hashCode) +
    (configuration.hashCode);

  @override
  String toString() => 'DeviceView[id=$id, revision=$revision, configuration=$configuration]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'revision'] = this.revision;
      json[r'configuration'] = this.configuration;
    return json;
  }

  /// Clones this instance of [DeviceView] and returns a new one where some of the
  /// properties have changed.
  DeviceView copyWith({
    String? id,
    int? revision,
    DeviceConfiguration? configuration,
  }) => DeviceView(
    id: id ?? this.id,
    revision: revision ?? this.revision,
    configuration: configuration ?? this.configuration,
  );

  /// Returns a new [DeviceView] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static DeviceView? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'), 'Required key "DeviceView[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "DeviceView[id]" has a null value in JSON.');
        assert(json.containsKey(r'revision'), 'Required key "DeviceView[revision]" is missing from JSON.');
        assert(json[r'revision'] != null, 'Required key "DeviceView[revision]" has a null value in JSON.');
        assert(json.containsKey(r'configuration'), 'Required key "DeviceView[configuration]" is missing from JSON.');
        assert(json[r'configuration'] != null, 'Required key "DeviceView[configuration]" has a null value in JSON.');
        return true;
      }());

      return DeviceView(
        id: mapValueOfType<String>(json, r'id')!,
        revision: mapValueOfType<int>(json, r'revision')!,
        configuration: DeviceConfiguration.fromJson(json[r'configuration'])!,
      );
    }
    return null;
  }

  static List<DeviceView> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DeviceView>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DeviceView.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, DeviceView> mapFromJson(dynamic json) {
    final map = <String, DeviceView>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = DeviceView.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of DeviceView-objects as value to a dart map
  static Map<String, List<DeviceView>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<DeviceView>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = DeviceView.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'revision',
    'configuration',
  };
}


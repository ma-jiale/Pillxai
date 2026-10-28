//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class Health {
  /// Returns a new [Health] instance.
  Health({
    required this.status,
    required this.serviceVersion,
  });

  final String status;

  final String serviceVersion;

  @override
  bool operator ==(Object other) => identical(this, other) || other is Health &&
    other.status == status &&
    other.serviceVersion == serviceVersion;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (status.hashCode) +
    (serviceVersion.hashCode);

  @override
  String toString() => 'Health[status=$status, serviceVersion=$serviceVersion]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'status'] = this.status;
      json[r'service_version'] = this.serviceVersion;
    return json;
  }

  /// Clones this instance of [Health] and returns a new one where some of the
  /// properties have changed.
  Health copyWith({
    String? status,
    String? serviceVersion,
  }) => Health(
    status: status ?? this.status,
    serviceVersion: serviceVersion ?? this.serviceVersion,
  );

  /// Returns a new [Health] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Health? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'status'), 'Required key "Health[status]" is missing from JSON.');
        assert(json[r'status'] != null, 'Required key "Health[status]" has a null value in JSON.');
        assert(json.containsKey(r'service_version'), 'Required key "Health[service_version]" is missing from JSON.');
        assert(json[r'service_version'] != null, 'Required key "Health[service_version]" has a null value in JSON.');
        return true;
      }());

      return Health(
        status: mapValueOfType<String>(json, r'status')!,
        serviceVersion: mapValueOfType<String>(json, r'service_version')!,
      );
    }
    return null;
  }

  static List<Health> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <Health>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Health.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Health> mapFromJson(dynamic json) {
    final map = <String, Health>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Health.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Health-objects as value to a dart map
  static Map<String, List<Health>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<Health>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Health.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'status',
    'service_version',
  };
}


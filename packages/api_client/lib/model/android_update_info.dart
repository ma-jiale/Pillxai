//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AndroidUpdateInfo {
  /// Returns a new [AndroidUpdateInfo] instance.
  AndroidUpdateInfo({
    required this.apiCompatibility,
    required this.release,
  });

  final int apiCompatibility;

  final AndroidRelease? release;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AndroidUpdateInfo &&
    other.apiCompatibility == apiCompatibility &&
    other.release == release;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (apiCompatibility.hashCode) +
    (release == null ? 0 : release!.hashCode);

  @override
  String toString() => 'AndroidUpdateInfo[apiCompatibility=$apiCompatibility, release=$release]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'api_compatibility'] = this.apiCompatibility;
    if (this.release != null) {
      json[r'release'] = this.release;
    } else {
      json[r'release'] = null;
    }
    return json;
  }

  /// Clones this instance of [AndroidUpdateInfo] and returns a new one where some of the
  /// properties have changed.
  AndroidUpdateInfo copyWith({
    int? apiCompatibility,
    AndroidRelease? release,
    bool releaseSetToNull = false,
  }) => AndroidUpdateInfo(
    apiCompatibility: apiCompatibility ?? this.apiCompatibility,
    release: releaseSetToNull ? null : release ?? this.release,
  );

  /// Returns a new [AndroidUpdateInfo] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AndroidUpdateInfo? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'api_compatibility'), 'Required key "AndroidUpdateInfo[api_compatibility]" is missing from JSON.');
        assert(json[r'api_compatibility'] != null, 'Required key "AndroidUpdateInfo[api_compatibility]" has a null value in JSON.');
        assert(json.containsKey(r'release'), 'Required key "AndroidUpdateInfo[release]" is missing from JSON.');
        return true;
      }());

      return AndroidUpdateInfo(
        apiCompatibility: mapValueOfType<int>(json, r'api_compatibility')!,
        release: AndroidRelease.fromJson(json[r'release']),
      );
    }
    return null;
  }

  static List<AndroidUpdateInfo> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AndroidUpdateInfo>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AndroidUpdateInfo.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AndroidUpdateInfo> mapFromJson(dynamic json) {
    final map = <String, AndroidUpdateInfo>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AndroidUpdateInfo.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AndroidUpdateInfo-objects as value to a dart map
  static Map<String, List<AndroidUpdateInfo>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AndroidUpdateInfo>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AndroidUpdateInfo.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'api_compatibility',
    'release',
  };
}


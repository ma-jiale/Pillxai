//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AndroidRelease {
  /// Returns a new [AndroidRelease] instance.
  AndroidRelease({
    required this.versionCode,
    required this.versionName,
    required this.packageName,
    required this.sha256,
    required this.sizeBytes,
    required this.minAndroidSdk,
    this.abis = const [],
    required this.minApi,
    required this.maxApi,
    required this.notes,
  });

  /// Minimum value: 1
  /// Maximum value: 2100000000
  final int versionCode;

  final String versionName;

  final String packageName;

  final String sha256;

  /// Minimum value: 1
  /// Maximum value: 536870912
  final int sizeBytes;

  /// Minimum value: 23
  /// Maximum value: 100
  final int minAndroidSdk;

  final List<String> abis;

  /// Minimum value: 1
  final int minApi;

  /// Minimum value: 1
  final int maxApi;

  final String notes;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AndroidRelease &&
    other.versionCode == versionCode &&
    other.versionName == versionName &&
    other.packageName == packageName &&
    other.sha256 == sha256 &&
    other.sizeBytes == sizeBytes &&
    other.minAndroidSdk == minAndroidSdk &&
    _deepEquality.equals(other.abis, abis) &&
    other.minApi == minApi &&
    other.maxApi == maxApi &&
    other.notes == notes;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (versionCode.hashCode) +
    (versionName.hashCode) +
    (packageName.hashCode) +
    (sha256.hashCode) +
    (sizeBytes.hashCode) +
    (minAndroidSdk.hashCode) +
    (abis.hashCode) +
    (minApi.hashCode) +
    (maxApi.hashCode) +
    (notes.hashCode);

  @override
  String toString() => 'AndroidRelease[versionCode=$versionCode, versionName=$versionName, packageName=$packageName, sha256=$sha256, sizeBytes=$sizeBytes, minAndroidSdk=$minAndroidSdk, abis=$abis, minApi=$minApi, maxApi=$maxApi, notes=$notes]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'version_code'] = this.versionCode;
      json[r'version_name'] = this.versionName;
      json[r'package_name'] = this.packageName;
      json[r'sha256'] = this.sha256;
      json[r'size_bytes'] = this.sizeBytes;
      json[r'min_android_sdk'] = this.minAndroidSdk;
      json[r'abis'] = this.abis;
      json[r'min_api'] = this.minApi;
      json[r'max_api'] = this.maxApi;
      json[r'notes'] = this.notes;
    return json;
  }

  /// Clones this instance of [AndroidRelease] and returns a new one where some of the
  /// properties have changed.
  AndroidRelease copyWith({
    int? versionCode,
    String? versionName,
    String? packageName,
    String? sha256,
    int? sizeBytes,
    int? minAndroidSdk,
    List<String>? abis,
    int? minApi,
    int? maxApi,
    String? notes,
  }) => AndroidRelease(
    versionCode: versionCode ?? this.versionCode,
    versionName: versionName ?? this.versionName,
    packageName: packageName ?? this.packageName,
    sha256: sha256 ?? this.sha256,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    minAndroidSdk: minAndroidSdk ?? this.minAndroidSdk,
    abis: abis ?? this.abis,
    minApi: minApi ?? this.minApi,
    maxApi: maxApi ?? this.maxApi,
    notes: notes ?? this.notes,
  );

  /// Returns a new [AndroidRelease] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AndroidRelease? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'version_code'), 'Required key "AndroidRelease[version_code]" is missing from JSON.');
        assert(json[r'version_code'] != null, 'Required key "AndroidRelease[version_code]" has a null value in JSON.');
        assert(json.containsKey(r'version_name'), 'Required key "AndroidRelease[version_name]" is missing from JSON.');
        assert(json[r'version_name'] != null, 'Required key "AndroidRelease[version_name]" has a null value in JSON.');
        assert(json.containsKey(r'package_name'), 'Required key "AndroidRelease[package_name]" is missing from JSON.');
        assert(json[r'package_name'] != null, 'Required key "AndroidRelease[package_name]" has a null value in JSON.');
        assert(json.containsKey(r'sha256'), 'Required key "AndroidRelease[sha256]" is missing from JSON.');
        assert(json[r'sha256'] != null, 'Required key "AndroidRelease[sha256]" has a null value in JSON.');
        assert(json.containsKey(r'size_bytes'), 'Required key "AndroidRelease[size_bytes]" is missing from JSON.');
        assert(json[r'size_bytes'] != null, 'Required key "AndroidRelease[size_bytes]" has a null value in JSON.');
        assert(json.containsKey(r'min_android_sdk'), 'Required key "AndroidRelease[min_android_sdk]" is missing from JSON.');
        assert(json[r'min_android_sdk'] != null, 'Required key "AndroidRelease[min_android_sdk]" has a null value in JSON.');
        assert(json.containsKey(r'abis'), 'Required key "AndroidRelease[abis]" is missing from JSON.');
        assert(json[r'abis'] != null, 'Required key "AndroidRelease[abis]" has a null value in JSON.');
        assert(json.containsKey(r'min_api'), 'Required key "AndroidRelease[min_api]" is missing from JSON.');
        assert(json[r'min_api'] != null, 'Required key "AndroidRelease[min_api]" has a null value in JSON.');
        assert(json.containsKey(r'max_api'), 'Required key "AndroidRelease[max_api]" is missing from JSON.');
        assert(json[r'max_api'] != null, 'Required key "AndroidRelease[max_api]" has a null value in JSON.');
        assert(json.containsKey(r'notes'), 'Required key "AndroidRelease[notes]" is missing from JSON.');
        assert(json[r'notes'] != null, 'Required key "AndroidRelease[notes]" has a null value in JSON.');
        return true;
      }());

      return AndroidRelease(
        versionCode: mapValueOfType<int>(json, r'version_code')!,
        versionName: mapValueOfType<String>(json, r'version_name')!,
        packageName: mapValueOfType<String>(json, r'package_name')!,
        sha256: mapValueOfType<String>(json, r'sha256')!,
        sizeBytes: mapValueOfType<int>(json, r'size_bytes')!,
        minAndroidSdk: mapValueOfType<int>(json, r'min_android_sdk')!,
        abis: json[r'abis'] is Iterable
            ? (json[r'abis'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        minApi: mapValueOfType<int>(json, r'min_api')!,
        maxApi: mapValueOfType<int>(json, r'max_api')!,
        notes: mapValueOfType<String>(json, r'notes')!,
      );
    }
    return null;
  }

  static List<AndroidRelease> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AndroidRelease>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AndroidRelease.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AndroidRelease> mapFromJson(dynamic json) {
    final map = <String, AndroidRelease>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AndroidRelease.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AndroidRelease-objects as value to a dart map
  static Map<String, List<AndroidRelease>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AndroidRelease>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AndroidRelease.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'version_code',
    'version_name',
    'package_name',
    'sha256',
    'size_bytes',
    'min_android_sdk',
    'abis',
    'min_api',
    'max_api',
    'notes',
  };
}


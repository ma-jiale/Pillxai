//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ChangePassword {
  /// Returns a new [ChangePassword] instance.
  ChangePassword({
    required this.password,
    required this.currentPassword,
  });

  final String password;

  final String currentPassword;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ChangePassword &&
    other.password == password &&
    other.currentPassword == currentPassword;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (password.hashCode) +
    (currentPassword.hashCode);

  @override
  String toString() => 'ChangePassword[password=$password, currentPassword=$currentPassword]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'password'] = this.password;
      json[r'current_password'] = this.currentPassword;
    return json;
  }

  /// Clones this instance of [ChangePassword] and returns a new one where some of the
  /// properties have changed.
  ChangePassword copyWith({
    String? password,
    String? currentPassword,
  }) => ChangePassword(
    password: password ?? this.password,
    currentPassword: currentPassword ?? this.currentPassword,
  );

  /// Returns a new [ChangePassword] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ChangePassword? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'password'), 'Required key "ChangePassword[password]" is missing from JSON.');
        assert(json[r'password'] != null, 'Required key "ChangePassword[password]" has a null value in JSON.');
        assert(json.containsKey(r'current_password'), 'Required key "ChangePassword[current_password]" is missing from JSON.');
        assert(json[r'current_password'] != null, 'Required key "ChangePassword[current_password]" has a null value in JSON.');
        return true;
      }());

      return ChangePassword(
        password: mapValueOfType<String>(json, r'password')!,
        currentPassword: mapValueOfType<String>(json, r'current_password')!,
      );
    }
    return null;
  }

  static List<ChangePassword> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ChangePassword>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ChangePassword.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ChangePassword> mapFromJson(dynamic json) {
    final map = <String, ChangePassword>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ChangePassword.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ChangePassword-objects as value to a dart map
  static Map<String, List<ChangePassword>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ChangePassword>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ChangePassword.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'password',
    'current_password',
  };
}


//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ResetPassword {
  /// Returns a new [ResetPassword] instance.
  ResetPassword({
    required this.password,
  });

  final String password;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ResetPassword &&
    other.password == password;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (password.hashCode);

  @override
  String toString() => 'ResetPassword[password=$password]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'password'] = this.password;
    return json;
  }

  /// Clones this instance of [ResetPassword] and returns a new one where some of the
  /// properties have changed.
  ResetPassword copyWith({
    String? password,
  }) => ResetPassword(
    password: password ?? this.password,
  );

  /// Returns a new [ResetPassword] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ResetPassword? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'password'), 'Required key "ResetPassword[password]" is missing from JSON.');
        assert(json[r'password'] != null, 'Required key "ResetPassword[password]" has a null value in JSON.');
        return true;
      }());

      return ResetPassword(
        password: mapValueOfType<String>(json, r'password')!,
      );
    }
    return null;
  }

  static List<ResetPassword> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ResetPassword>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ResetPassword.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ResetPassword> mapFromJson(dynamic json) {
    final map = <String, ResetPassword>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ResetPassword.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ResetPassword-objects as value to a dart map
  static Map<String, List<ResetPassword>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ResetPassword>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ResetPassword.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'password',
  };
}


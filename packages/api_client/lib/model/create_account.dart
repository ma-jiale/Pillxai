//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CreateAccount {
  /// Returns a new [CreateAccount] instance.
  CreateAccount({
    required this.username,
    required this.displayName,
    required this.password,
    this.role = Role.staff,
    this.canMaintain = false,
  });

  final String username;

  final String displayName;

  final String password;

  final Role role;

  final bool canMaintain;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CreateAccount &&
    other.username == username &&
    other.displayName == displayName &&
    other.password == password &&
    other.role == role &&
    other.canMaintain == canMaintain;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (username.hashCode) +
    (displayName.hashCode) +
    (password.hashCode) +
    (role.hashCode) +
    (canMaintain.hashCode);

  @override
  String toString() => 'CreateAccount[username=$username, displayName=$displayName, password=$password, role=$role, canMaintain=$canMaintain]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'username'] = this.username;
      json[r'display_name'] = this.displayName;
      json[r'password'] = this.password;
      json[r'role'] = this.role;
      json[r'can_maintain'] = this.canMaintain;
    return json;
  }

  /// Clones this instance of [CreateAccount] and returns a new one where some of the
  /// properties have changed.
  CreateAccount copyWith({
    String? username,
    String? displayName,
    String? password,
    Role? role,
    bool? canMaintain,
  }) => CreateAccount(
    username: username ?? this.username,
    displayName: displayName ?? this.displayName,
    password: password ?? this.password,
    role: role ?? this.role,
    canMaintain: canMaintain ?? this.canMaintain,
  );

  /// Returns a new [CreateAccount] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CreateAccount? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'username'), 'Required key "CreateAccount[username]" is missing from JSON.');
        assert(json[r'username'] != null, 'Required key "CreateAccount[username]" has a null value in JSON.');
        assert(json.containsKey(r'display_name'), 'Required key "CreateAccount[display_name]" is missing from JSON.');
        assert(json[r'display_name'] != null, 'Required key "CreateAccount[display_name]" has a null value in JSON.');
        assert(json.containsKey(r'password'), 'Required key "CreateAccount[password]" is missing from JSON.');
        assert(json[r'password'] != null, 'Required key "CreateAccount[password]" has a null value in JSON.');
        return true;
      }());

      return CreateAccount(
        username: mapValueOfType<String>(json, r'username')!,
        displayName: mapValueOfType<String>(json, r'display_name')!,
        password: mapValueOfType<String>(json, r'password')!,
        role: Role.fromJson(json[r'role']) ?? Role.staff,
        canMaintain: mapValueOfType<bool>(json, r'can_maintain') ?? false,
      );
    }
    return null;
  }

  static List<CreateAccount> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreateAccount>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreateAccount.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CreateAccount> mapFromJson(dynamic json) {
    final map = <String, CreateAccount>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CreateAccount.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CreateAccount-objects as value to a dart map
  static Map<String, List<CreateAccount>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CreateAccount>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CreateAccount.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'username',
    'display_name',
    'password',
  };
}


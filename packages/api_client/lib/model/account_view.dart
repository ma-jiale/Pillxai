//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AccountView {
  /// Returns a new [AccountView] instance.
  AccountView({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.canMaintain,
    required this.active,
    required this.revision,
  });

  final String id;

  final String username;

  final String displayName;

  final Role role;

  final bool canMaintain;

  final bool active;

  final int revision;

  @override
  bool operator ==(Object other) => identical(this, other) || other is AccountView &&
    other.id == id &&
    other.username == username &&
    other.displayName == displayName &&
    other.role == role &&
    other.canMaintain == canMaintain &&
    other.active == active &&
    other.revision == revision;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (username.hashCode) +
    (displayName.hashCode) +
    (role.hashCode) +
    (canMaintain.hashCode) +
    (active.hashCode) +
    (revision.hashCode);

  @override
  String toString() => 'AccountView[id=$id, username=$username, displayName=$displayName, role=$role, canMaintain=$canMaintain, active=$active, revision=$revision]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'username'] = this.username;
      json[r'display_name'] = this.displayName;
      json[r'role'] = this.role;
      json[r'can_maintain'] = this.canMaintain;
      json[r'active'] = this.active;
      json[r'revision'] = this.revision;
    return json;
  }

  /// Clones this instance of [AccountView] and returns a new one where some of the
  /// properties have changed.
  AccountView copyWith({
    String? id,
    String? username,
    String? displayName,
    Role? role,
    bool? canMaintain,
    bool? active,
    int? revision,
  }) => AccountView(
    id: id ?? this.id,
    username: username ?? this.username,
    displayName: displayName ?? this.displayName,
    role: role ?? this.role,
    canMaintain: canMaintain ?? this.canMaintain,
    active: active ?? this.active,
    revision: revision ?? this.revision,
  );

  /// Returns a new [AccountView] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AccountView? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'), 'Required key "AccountView[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "AccountView[id]" has a null value in JSON.');
        assert(json.containsKey(r'username'), 'Required key "AccountView[username]" is missing from JSON.');
        assert(json[r'username'] != null, 'Required key "AccountView[username]" has a null value in JSON.');
        assert(json.containsKey(r'display_name'), 'Required key "AccountView[display_name]" is missing from JSON.');
        assert(json[r'display_name'] != null, 'Required key "AccountView[display_name]" has a null value in JSON.');
        assert(json.containsKey(r'role'), 'Required key "AccountView[role]" is missing from JSON.');
        assert(json[r'role'] != null, 'Required key "AccountView[role]" has a null value in JSON.');
        assert(json.containsKey(r'can_maintain'), 'Required key "AccountView[can_maintain]" is missing from JSON.');
        assert(json[r'can_maintain'] != null, 'Required key "AccountView[can_maintain]" has a null value in JSON.');
        assert(json.containsKey(r'active'), 'Required key "AccountView[active]" is missing from JSON.');
        assert(json[r'active'] != null, 'Required key "AccountView[active]" has a null value in JSON.');
        assert(json.containsKey(r'revision'), 'Required key "AccountView[revision]" is missing from JSON.');
        assert(json[r'revision'] != null, 'Required key "AccountView[revision]" has a null value in JSON.');
        return true;
      }());

      return AccountView(
        id: mapValueOfType<String>(json, r'id')!,
        username: mapValueOfType<String>(json, r'username')!,
        displayName: mapValueOfType<String>(json, r'display_name')!,
        role: Role.fromJson(json[r'role'])!,
        canMaintain: mapValueOfType<bool>(json, r'can_maintain')!,
        active: mapValueOfType<bool>(json, r'active')!,
        revision: mapValueOfType<int>(json, r'revision')!,
      );
    }
    return null;
  }

  static List<AccountView> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <AccountView>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AccountView.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AccountView> mapFromJson(dynamic json) {
    final map = <String, AccountView>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AccountView.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AccountView-objects as value to a dart map
  static Map<String, List<AccountView>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<AccountView>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AccountView.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'username',
    'display_name',
    'role',
    'can_maintain',
    'active',
    'revision',
  };
}


//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class UpdateAccount {
  /// Returns a new [UpdateAccount] instance.
  UpdateAccount({
    required this.expectedRevision,
    required this.displayName,
    required this.active,
    required this.canMaintain,
  });

  /// Minimum value: 1
  final int expectedRevision;

  final String displayName;

  final bool active;

  final bool canMaintain;

  @override
  bool operator ==(Object other) => identical(this, other) || other is UpdateAccount &&
    other.expectedRevision == expectedRevision &&
    other.displayName == displayName &&
    other.active == active &&
    other.canMaintain == canMaintain;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (expectedRevision.hashCode) +
    (displayName.hashCode) +
    (active.hashCode) +
    (canMaintain.hashCode);

  @override
  String toString() => 'UpdateAccount[expectedRevision=$expectedRevision, displayName=$displayName, active=$active, canMaintain=$canMaintain]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'expected_revision'] = this.expectedRevision;
      json[r'display_name'] = this.displayName;
      json[r'active'] = this.active;
      json[r'can_maintain'] = this.canMaintain;
    return json;
  }

  /// Clones this instance of [UpdateAccount] and returns a new one where some of the
  /// properties have changed.
  UpdateAccount copyWith({
    int? expectedRevision,
    String? displayName,
    bool? active,
    bool? canMaintain,
  }) => UpdateAccount(
    expectedRevision: expectedRevision ?? this.expectedRevision,
    displayName: displayName ?? this.displayName,
    active: active ?? this.active,
    canMaintain: canMaintain ?? this.canMaintain,
  );

  /// Returns a new [UpdateAccount] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static UpdateAccount? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'expected_revision'), 'Required key "UpdateAccount[expected_revision]" is missing from JSON.');
        assert(json[r'expected_revision'] != null, 'Required key "UpdateAccount[expected_revision]" has a null value in JSON.');
        assert(json.containsKey(r'display_name'), 'Required key "UpdateAccount[display_name]" is missing from JSON.');
        assert(json[r'display_name'] != null, 'Required key "UpdateAccount[display_name]" has a null value in JSON.');
        assert(json.containsKey(r'active'), 'Required key "UpdateAccount[active]" is missing from JSON.');
        assert(json[r'active'] != null, 'Required key "UpdateAccount[active]" has a null value in JSON.');
        assert(json.containsKey(r'can_maintain'), 'Required key "UpdateAccount[can_maintain]" is missing from JSON.');
        assert(json[r'can_maintain'] != null, 'Required key "UpdateAccount[can_maintain]" has a null value in JSON.');
        return true;
      }());

      return UpdateAccount(
        expectedRevision: mapValueOfType<int>(json, r'expected_revision')!,
        displayName: mapValueOfType<String>(json, r'display_name')!,
        active: mapValueOfType<bool>(json, r'active')!,
        canMaintain: mapValueOfType<bool>(json, r'can_maintain')!,
      );
    }
    return null;
  }

  static List<UpdateAccount> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UpdateAccount>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UpdateAccount.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, UpdateAccount> mapFromJson(dynamic json) {
    final map = <String, UpdateAccount>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = UpdateAccount.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of UpdateAccount-objects as value to a dart map
  static Map<String, List<UpdateAccount>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<UpdateAccount>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = UpdateAccount.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'expected_revision',
    'display_name',
    'active',
    'can_maintain',
  };
}


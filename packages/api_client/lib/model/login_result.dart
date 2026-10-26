//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class LoginResult {
  /// Returns a new [LoginResult] instance.
  LoginResult({
    required this.accessToken,
    required this.expiresAt,
    required this.account,
  });

  final String accessToken;

  final DateTime expiresAt;

  final AccountView account;

  @override
  bool operator ==(Object other) => identical(this, other) || other is LoginResult &&
    other.accessToken == accessToken &&
    other.expiresAt == expiresAt &&
    other.account == account;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (accessToken.hashCode) +
    (expiresAt.hashCode) +
    (account.hashCode);

  @override
  String toString() => 'LoginResult[accessToken=$accessToken, expiresAt=$expiresAt, account=$account]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'access_token'] = this.accessToken;
      json[r'expires_at'] = this.expiresAt.toUtc().toIso8601String();
      json[r'account'] = this.account;
    return json;
  }

  /// Clones this instance of [LoginResult] and returns a new one where some of the
  /// properties have changed.
  LoginResult copyWith({
    String? accessToken,
    DateTime? expiresAt,
    AccountView? account,
  }) => LoginResult(
    accessToken: accessToken ?? this.accessToken,
    expiresAt: expiresAt ?? this.expiresAt,
    account: account ?? this.account,
  );

  /// Returns a new [LoginResult] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static LoginResult? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'access_token'), 'Required key "LoginResult[access_token]" is missing from JSON.');
        assert(json[r'access_token'] != null, 'Required key "LoginResult[access_token]" has a null value in JSON.');
        assert(json.containsKey(r'expires_at'), 'Required key "LoginResult[expires_at]" is missing from JSON.');
        assert(json[r'expires_at'] != null, 'Required key "LoginResult[expires_at]" has a null value in JSON.');
        assert(json.containsKey(r'account'), 'Required key "LoginResult[account]" is missing from JSON.');
        assert(json[r'account'] != null, 'Required key "LoginResult[account]" has a null value in JSON.');
        return true;
      }());

      return LoginResult(
        accessToken: mapValueOfType<String>(json, r'access_token')!,
        expiresAt: mapDateTime(json, r'expires_at', r'')!,
        account: AccountView.fromJson(json[r'account'])!,
      );
    }
    return null;
  }

  static List<LoginResult> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <LoginResult>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = LoginResult.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, LoginResult> mapFromJson(dynamic json) {
    final map = <String, LoginResult>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = LoginResult.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of LoginResult-objects as value to a dart map
  static Map<String, List<LoginResult>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<LoginResult>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = LoginResult.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'access_token',
    'expires_at',
    'account',
  };
}


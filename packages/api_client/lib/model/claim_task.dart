//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ClaimTask {
  /// Returns a new [ClaimTask] instance.
  ClaimTask({
    required this.planId,
    required this.deviceId,
    required this.terminalId,
  });

  final String planId;

  final String deviceId;

  final String terminalId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ClaimTask &&
    other.planId == planId &&
    other.deviceId == deviceId &&
    other.terminalId == terminalId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (planId.hashCode) +
    (deviceId.hashCode) +
    (terminalId.hashCode);

  @override
  String toString() => 'ClaimTask[planId=$planId, deviceId=$deviceId, terminalId=$terminalId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'plan_id'] = this.planId;
      json[r'device_id'] = this.deviceId;
      json[r'terminal_id'] = this.terminalId;
    return json;
  }

  /// Clones this instance of [ClaimTask] and returns a new one where some of the
  /// properties have changed.
  ClaimTask copyWith({
    String? planId,
    String? deviceId,
    String? terminalId,
  }) => ClaimTask(
    planId: planId ?? this.planId,
    deviceId: deviceId ?? this.deviceId,
    terminalId: terminalId ?? this.terminalId,
  );

  /// Returns a new [ClaimTask] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ClaimTask? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'plan_id'), 'Required key "ClaimTask[plan_id]" is missing from JSON.');
        assert(json[r'plan_id'] != null, 'Required key "ClaimTask[plan_id]" has a null value in JSON.');
        assert(json.containsKey(r'device_id'), 'Required key "ClaimTask[device_id]" is missing from JSON.');
        assert(json[r'device_id'] != null, 'Required key "ClaimTask[device_id]" has a null value in JSON.');
        assert(json.containsKey(r'terminal_id'), 'Required key "ClaimTask[terminal_id]" is missing from JSON.');
        assert(json[r'terminal_id'] != null, 'Required key "ClaimTask[terminal_id]" has a null value in JSON.');
        return true;
      }());

      return ClaimTask(
        planId: mapValueOfType<String>(json, r'plan_id')!,
        deviceId: mapValueOfType<String>(json, r'device_id')!,
        terminalId: mapValueOfType<String>(json, r'terminal_id')!,
      );
    }
    return null;
  }

  static List<ClaimTask> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ClaimTask>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ClaimTask.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ClaimTask> mapFromJson(dynamic json) {
    final map = <String, ClaimTask>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ClaimTask.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ClaimTask-objects as value to a dart map
  static Map<String, List<ClaimTask>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ClaimTask>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ClaimTask.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'plan_id',
    'device_id',
    'terminal_id',
  };
}


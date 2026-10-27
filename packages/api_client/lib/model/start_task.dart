//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class StartTask {
  /// Returns a new [StartTask] instance.
  StartTask({
    required this.terminalId,
    required this.expectedRevision,
    required this.uid,
    required this.observedAt,
  });

  final String terminalId;

  /// Minimum value: 1
  final int expectedRevision;

  final String uid;

  final DateTime observedAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is StartTask &&
    other.terminalId == terminalId &&
    other.expectedRevision == expectedRevision &&
    other.uid == uid &&
    other.observedAt == observedAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (terminalId.hashCode) +
    (expectedRevision.hashCode) +
    (uid.hashCode) +
    (observedAt.hashCode);

  @override
  String toString() => 'StartTask[terminalId=$terminalId, expectedRevision=$expectedRevision, uid=$uid, observedAt=$observedAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'terminal_id'] = this.terminalId;
      json[r'expected_revision'] = this.expectedRevision;
      json[r'uid'] = this.uid;
      json[r'observed_at'] = this.observedAt.toUtc().toIso8601String();
    return json;
  }

  /// Clones this instance of [StartTask] and returns a new one where some of the
  /// properties have changed.
  StartTask copyWith({
    String? terminalId,
    int? expectedRevision,
    String? uid,
    DateTime? observedAt,
  }) => StartTask(
    terminalId: terminalId ?? this.terminalId,
    expectedRevision: expectedRevision ?? this.expectedRevision,
    uid: uid ?? this.uid,
    observedAt: observedAt ?? this.observedAt,
  );

  /// Returns a new [StartTask] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static StartTask? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'terminal_id'), 'Required key "StartTask[terminal_id]" is missing from JSON.');
        assert(json[r'terminal_id'] != null, 'Required key "StartTask[terminal_id]" has a null value in JSON.');
        assert(json.containsKey(r'expected_revision'), 'Required key "StartTask[expected_revision]" is missing from JSON.');
        assert(json[r'expected_revision'] != null, 'Required key "StartTask[expected_revision]" has a null value in JSON.');
        assert(json.containsKey(r'uid'), 'Required key "StartTask[uid]" is missing from JSON.');
        assert(json[r'uid'] != null, 'Required key "StartTask[uid]" has a null value in JSON.');
        assert(json.containsKey(r'observed_at'), 'Required key "StartTask[observed_at]" is missing from JSON.');
        assert(json[r'observed_at'] != null, 'Required key "StartTask[observed_at]" has a null value in JSON.');
        return true;
      }());

      return StartTask(
        terminalId: mapValueOfType<String>(json, r'terminal_id')!,
        expectedRevision: mapValueOfType<int>(json, r'expected_revision')!,
        uid: mapValueOfType<String>(json, r'uid')!,
        observedAt: mapDateTime(json, r'observed_at', r'')!,
      );
    }
    return null;
  }

  static List<StartTask> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <StartTask>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = StartTask.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, StartTask> mapFromJson(dynamic json) {
    final map = <String, StartTask>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = StartTask.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of StartTask-objects as value to a dart map
  static Map<String, List<StartTask>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<StartTask>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = StartTask.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'terminal_id',
    'expected_revision',
    'uid',
    'observed_at',
  };
}


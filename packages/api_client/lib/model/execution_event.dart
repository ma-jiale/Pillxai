//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ExecutionEvent {
  /// Returns a new [ExecutionEvent] instance.
  ExecutionEvent({
    required this.sequence,
    required this.kind,
    required this.batch,
    required this.at,
    this.detail = const {},
  });

  /// Minimum value: 1
  final int sequence;

  final String kind;

  /// Minimum value: 0
  final int batch;

  final DateTime at;

  final Map<String, Object> detail;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ExecutionEvent &&
    other.sequence == sequence &&
    other.kind == kind &&
    other.batch == batch &&
    other.at == at &&
    _deepEquality.equals(other.detail, detail);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (sequence.hashCode) +
    (kind.hashCode) +
    (batch.hashCode) +
    (at.hashCode) +
    (detail.hashCode);

  @override
  String toString() => 'ExecutionEvent[sequence=$sequence, kind=$kind, batch=$batch, at=$at, detail=$detail]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'sequence'] = this.sequence;
      json[r'kind'] = this.kind;
      json[r'batch'] = this.batch;
      json[r'at'] = this.at.toUtc().toIso8601String();
      json[r'detail'] = this.detail;
    return json;
  }

  /// Clones this instance of [ExecutionEvent] and returns a new one where some of the
  /// properties have changed.
  ExecutionEvent copyWith({
    int? sequence,
    String? kind,
    int? batch,
    DateTime? at,
    Map<String, Object>? detail,
  }) => ExecutionEvent(
    sequence: sequence ?? this.sequence,
    kind: kind ?? this.kind,
    batch: batch ?? this.batch,
    at: at ?? this.at,
    detail: detail ?? this.detail,
  );

  /// Returns a new [ExecutionEvent] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ExecutionEvent? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'sequence'), 'Required key "ExecutionEvent[sequence]" is missing from JSON.');
        assert(json[r'sequence'] != null, 'Required key "ExecutionEvent[sequence]" has a null value in JSON.');
        assert(json.containsKey(r'kind'), 'Required key "ExecutionEvent[kind]" is missing from JSON.');
        assert(json[r'kind'] != null, 'Required key "ExecutionEvent[kind]" has a null value in JSON.');
        assert(json.containsKey(r'batch'), 'Required key "ExecutionEvent[batch]" is missing from JSON.');
        assert(json[r'batch'] != null, 'Required key "ExecutionEvent[batch]" has a null value in JSON.');
        assert(json.containsKey(r'at'), 'Required key "ExecutionEvent[at]" is missing from JSON.');
        assert(json[r'at'] != null, 'Required key "ExecutionEvent[at]" has a null value in JSON.');
        return true;
      }());

      return ExecutionEvent(
        sequence: mapValueOfType<int>(json, r'sequence')!,
        kind: mapValueOfType<String>(json, r'kind')!,
        batch: mapValueOfType<int>(json, r'batch')!,
        at: mapDateTime(json, r'at', r'')!,
        detail: mapCastOfType<String, Object>(json, r'detail') ?? const {},
      );
    }
    return null;
  }

  static List<ExecutionEvent> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ExecutionEvent>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ExecutionEvent.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ExecutionEvent> mapFromJson(dynamic json) {
    final map = <String, ExecutionEvent>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ExecutionEvent.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ExecutionEvent-objects as value to a dart map
  static Map<String, List<ExecutionEvent>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ExecutionEvent>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ExecutionEvent.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'sequence',
    'kind',
    'batch',
    'at',
  };
}


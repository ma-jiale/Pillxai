//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SyncEvents {
  /// Returns a new [SyncEvents] instance.
  SyncEvents({
    required this.terminalId,
    this.events = const [],
  });

  final String terminalId;

  final List<ExecutionEvent> events;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SyncEvents &&
    other.terminalId == terminalId &&
    _deepEquality.equals(other.events, events);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (terminalId.hashCode) +
    (events.hashCode);

  @override
  String toString() => 'SyncEvents[terminalId=$terminalId, events=$events]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'terminal_id'] = this.terminalId;
      json[r'events'] = this.events;
    return json;
  }

  /// Clones this instance of [SyncEvents] and returns a new one where some of the
  /// properties have changed.
  SyncEvents copyWith({
    String? terminalId,
    List<ExecutionEvent>? events,
  }) => SyncEvents(
    terminalId: terminalId ?? this.terminalId,
    events: events ?? this.events,
  );

  /// Returns a new [SyncEvents] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SyncEvents? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'terminal_id'), 'Required key "SyncEvents[terminal_id]" is missing from JSON.');
        assert(json[r'terminal_id'] != null, 'Required key "SyncEvents[terminal_id]" has a null value in JSON.');
        assert(json.containsKey(r'events'), 'Required key "SyncEvents[events]" is missing from JSON.');
        assert(json[r'events'] != null, 'Required key "SyncEvents[events]" has a null value in JSON.');
        return true;
      }());

      return SyncEvents(
        terminalId: mapValueOfType<String>(json, r'terminal_id')!,
        events: ExecutionEvent.listFromJson(json[r'events']),
      );
    }
    return null;
  }

  static List<SyncEvents> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SyncEvents>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SyncEvents.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SyncEvents> mapFromJson(dynamic json) {
    final map = <String, SyncEvents>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SyncEvents.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SyncEvents-objects as value to a dart map
  static Map<String, List<SyncEvents>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SyncEvents>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SyncEvents.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'terminal_id',
    'events',
  };
}


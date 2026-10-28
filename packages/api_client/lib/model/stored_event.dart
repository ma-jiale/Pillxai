//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class StoredEvent {
  /// Returns a new [StoredEvent] instance.
  StoredEvent({
    required this.sequence,
    required this.kind,
    required this.batch,
    required this.at,
    this.detail = const {},
    required this.receivedAt,
  });

  /// Minimum value: 1
  final int sequence;

  final String kind;

  /// Minimum value: 0
  final int batch;

  final DateTime at;

  final Map<String, Object> detail;

  final DateTime receivedAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is StoredEvent &&
    other.sequence == sequence &&
    other.kind == kind &&
    other.batch == batch &&
    other.at == at &&
    _deepEquality.equals(other.detail, detail) &&
    other.receivedAt == receivedAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (sequence.hashCode) +
    (kind.hashCode) +
    (batch.hashCode) +
    (at.hashCode) +
    (detail.hashCode) +
    (receivedAt.hashCode);

  @override
  String toString() => 'StoredEvent[sequence=$sequence, kind=$kind, batch=$batch, at=$at, detail=$detail, receivedAt=$receivedAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'sequence'] = this.sequence;
      json[r'kind'] = this.kind;
      json[r'batch'] = this.batch;
      json[r'at'] = this.at.toUtc().toIso8601String();
      json[r'detail'] = this.detail;
      json[r'received_at'] = this.receivedAt.toUtc().toIso8601String();
    return json;
  }

  /// Clones this instance of [StoredEvent] and returns a new one where some of the
  /// properties have changed.
  StoredEvent copyWith({
    int? sequence,
    String? kind,
    int? batch,
    DateTime? at,
    Map<String, Object>? detail,
    DateTime? receivedAt,
  }) => StoredEvent(
    sequence: sequence ?? this.sequence,
    kind: kind ?? this.kind,
    batch: batch ?? this.batch,
    at: at ?? this.at,
    detail: detail ?? this.detail,
    receivedAt: receivedAt ?? this.receivedAt,
  );

  /// Returns a new [StoredEvent] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static StoredEvent? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'sequence'), 'Required key "StoredEvent[sequence]" is missing from JSON.');
        assert(json[r'sequence'] != null, 'Required key "StoredEvent[sequence]" has a null value in JSON.');
        assert(json.containsKey(r'kind'), 'Required key "StoredEvent[kind]" is missing from JSON.');
        assert(json[r'kind'] != null, 'Required key "StoredEvent[kind]" has a null value in JSON.');
        assert(json.containsKey(r'batch'), 'Required key "StoredEvent[batch]" is missing from JSON.');
        assert(json[r'batch'] != null, 'Required key "StoredEvent[batch]" has a null value in JSON.');
        assert(json.containsKey(r'at'), 'Required key "StoredEvent[at]" is missing from JSON.');
        assert(json[r'at'] != null, 'Required key "StoredEvent[at]" has a null value in JSON.');
        assert(json.containsKey(r'received_at'), 'Required key "StoredEvent[received_at]" is missing from JSON.');
        assert(json[r'received_at'] != null, 'Required key "StoredEvent[received_at]" has a null value in JSON.');
        return true;
      }());

      return StoredEvent(
        sequence: mapValueOfType<int>(json, r'sequence')!,
        kind: mapValueOfType<String>(json, r'kind')!,
        batch: mapValueOfType<int>(json, r'batch')!,
        at: mapDateTime(json, r'at', r'')!,
        detail: mapCastOfType<String, Object>(json, r'detail') ?? const {},
        receivedAt: mapDateTime(json, r'received_at', r'')!,
      );
    }
    return null;
  }

  static List<StoredEvent> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <StoredEvent>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = StoredEvent.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, StoredEvent> mapFromJson(dynamic json) {
    final map = <String, StoredEvent>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = StoredEvent.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of StoredEvent-objects as value to a dart map
  static Map<String, List<StoredEvent>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<StoredEvent>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = StoredEvent.listFromJson(entry.value, growable: growable,);
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
    'received_at',
  };
}


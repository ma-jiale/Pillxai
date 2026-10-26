//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PlanPreview {
  /// Returns a new [PlanPreview] instance.
  PlanPreview({
    required this.snapshot,
    required this.current,
    required this.message,
  });

  final PlanSnapshot snapshot;

  final bool current;

  final String message;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PlanPreview &&
    other.snapshot == snapshot &&
    other.current == current &&
    other.message == message;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (snapshot.hashCode) +
    (current.hashCode) +
    (message.hashCode);

  @override
  String toString() => 'PlanPreview[snapshot=$snapshot, current=$current, message=$message]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'snapshot'] = this.snapshot;
      json[r'current'] = this.current;
      json[r'message'] = this.message;
    return json;
  }

  /// Clones this instance of [PlanPreview] and returns a new one where some of the
  /// properties have changed.
  PlanPreview copyWith({
    PlanSnapshot? snapshot,
    bool? current,
    String? message,
  }) => PlanPreview(
    snapshot: snapshot ?? this.snapshot,
    current: current ?? this.current,
    message: message ?? this.message,
  );

  /// Returns a new [PlanPreview] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PlanPreview? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'snapshot'), 'Required key "PlanPreview[snapshot]" is missing from JSON.');
        assert(json[r'snapshot'] != null, 'Required key "PlanPreview[snapshot]" has a null value in JSON.');
        assert(json.containsKey(r'current'), 'Required key "PlanPreview[current]" is missing from JSON.');
        assert(json[r'current'] != null, 'Required key "PlanPreview[current]" has a null value in JSON.');
        assert(json.containsKey(r'message'), 'Required key "PlanPreview[message]" is missing from JSON.');
        assert(json[r'message'] != null, 'Required key "PlanPreview[message]" has a null value in JSON.');
        return true;
      }());

      return PlanPreview(
        snapshot: PlanSnapshot.fromJson(json[r'snapshot'])!,
        current: mapValueOfType<bool>(json, r'current')!,
        message: mapValueOfType<String>(json, r'message')!,
      );
    }
    return null;
  }

  static List<PlanPreview> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PlanPreview>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PlanPreview.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PlanPreview> mapFromJson(dynamic json) {
    final map = <String, PlanPreview>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PlanPreview.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PlanPreview-objects as value to a dart map
  static Map<String, List<PlanPreview>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PlanPreview>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PlanPreview.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'snapshot',
    'current',
    'message',
  };
}


//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SaveResident {
  /// Returns a new [SaveResident] instance.
  SaveResident({
    required this.expectedRevision,
    required this.data,
  });

  /// Minimum value: 0
  final int expectedRevision;

  final ResidentData data;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SaveResident &&
    other.expectedRevision == expectedRevision &&
    other.data == data;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (expectedRevision.hashCode) +
    (data.hashCode);

  @override
  String toString() => 'SaveResident[expectedRevision=$expectedRevision, data=$data]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'expected_revision'] = this.expectedRevision;
      json[r'data'] = this.data;
    return json;
  }

  /// Clones this instance of [SaveResident] and returns a new one where some of the
  /// properties have changed.
  SaveResident copyWith({
    int? expectedRevision,
    ResidentData? data,
  }) => SaveResident(
    expectedRevision: expectedRevision ?? this.expectedRevision,
    data: data ?? this.data,
  );

  /// Returns a new [SaveResident] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SaveResident? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'expected_revision'), 'Required key "SaveResident[expected_revision]" is missing from JSON.');
        assert(json[r'expected_revision'] != null, 'Required key "SaveResident[expected_revision]" has a null value in JSON.');
        assert(json.containsKey(r'data'), 'Required key "SaveResident[data]" is missing from JSON.');
        assert(json[r'data'] != null, 'Required key "SaveResident[data]" has a null value in JSON.');
        return true;
      }());

      return SaveResident(
        expectedRevision: mapValueOfType<int>(json, r'expected_revision')!,
        data: ResidentData.fromJson(json[r'data'])!,
      );
    }
    return null;
  }

  static List<SaveResident> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SaveResident>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SaveResident.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SaveResident> mapFromJson(dynamic json) {
    final map = <String, SaveResident>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SaveResident.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SaveResident-objects as value to a dart map
  static Map<String, List<SaveResident>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SaveResident>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SaveResident.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'expected_revision',
    'data',
  };
}


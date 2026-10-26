//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SavePrescription {
  /// Returns a new [SavePrescription] instance.
  SavePrescription({
    required this.expectedRevision,
    required this.data,
  });

  /// Minimum value: 0
  final int expectedRevision;

  final PrescriptionData data;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SavePrescription &&
    other.expectedRevision == expectedRevision &&
    other.data == data;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (expectedRevision.hashCode) +
    (data.hashCode);

  @override
  String toString() => 'SavePrescription[expectedRevision=$expectedRevision, data=$data]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'expected_revision'] = this.expectedRevision;
      json[r'data'] = this.data;
    return json;
  }

  /// Clones this instance of [SavePrescription] and returns a new one where some of the
  /// properties have changed.
  SavePrescription copyWith({
    int? expectedRevision,
    PrescriptionData? data,
  }) => SavePrescription(
    expectedRevision: expectedRevision ?? this.expectedRevision,
    data: data ?? this.data,
  );

  /// Returns a new [SavePrescription] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SavePrescription? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'expected_revision'), 'Required key "SavePrescription[expected_revision]" is missing from JSON.');
        assert(json[r'expected_revision'] != null, 'Required key "SavePrescription[expected_revision]" has a null value in JSON.');
        assert(json.containsKey(r'data'), 'Required key "SavePrescription[data]" is missing from JSON.');
        assert(json[r'data'] != null, 'Required key "SavePrescription[data]" has a null value in JSON.');
        return true;
      }());

      return SavePrescription(
        expectedRevision: mapValueOfType<int>(json, r'expected_revision')!,
        data: PrescriptionData.fromJson(json[r'data'])!,
      );
    }
    return null;
  }

  static List<SavePrescription> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SavePrescription>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SavePrescription.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SavePrescription> mapFromJson(dynamic json) {
    final map = <String, SavePrescription>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SavePrescription.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SavePrescription-objects as value to a dart map
  static Map<String, List<SavePrescription>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SavePrescription>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SavePrescription.listFromJson(entry.value, growable: growable,);
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


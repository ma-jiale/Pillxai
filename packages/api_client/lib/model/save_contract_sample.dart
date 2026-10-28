//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SaveContractSample {
  /// Returns a new [SaveContractSample] instance.
  SaveContractSample({
    required this.expectedRevision,
    required this.sample,
  });

  /// Minimum value: 0
  final int expectedRevision;

  final ContractSample sample;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SaveContractSample &&
    other.expectedRevision == expectedRevision &&
    other.sample == sample;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (expectedRevision.hashCode) +
    (sample.hashCode);

  @override
  String toString() => 'SaveContractSample[expectedRevision=$expectedRevision, sample=$sample]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'expected_revision'] = this.expectedRevision;
      json[r'sample'] = this.sample;
    return json;
  }

  /// Clones this instance of [SaveContractSample] and returns a new one where some of the
  /// properties have changed.
  SaveContractSample copyWith({
    int? expectedRevision,
    ContractSample? sample,
  }) => SaveContractSample(
    expectedRevision: expectedRevision ?? this.expectedRevision,
    sample: sample ?? this.sample,
  );

  /// Returns a new [SaveContractSample] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SaveContractSample? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'expected_revision'), 'Required key "SaveContractSample[expected_revision]" is missing from JSON.');
        assert(json[r'expected_revision'] != null, 'Required key "SaveContractSample[expected_revision]" has a null value in JSON.');
        assert(json.containsKey(r'sample'), 'Required key "SaveContractSample[sample]" is missing from JSON.');
        assert(json[r'sample'] != null, 'Required key "SaveContractSample[sample]" has a null value in JSON.');
        return true;
      }());

      return SaveContractSample(
        expectedRevision: mapValueOfType<int>(json, r'expected_revision')!,
        sample: ContractSample.fromJson(json[r'sample'])!,
      );
    }
    return null;
  }

  static List<SaveContractSample> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SaveContractSample>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SaveContractSample.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SaveContractSample> mapFromJson(dynamic json) {
    final map = <String, SaveContractSample>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SaveContractSample.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SaveContractSample-objects as value to a dart map
  static Map<String, List<SaveContractSample>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SaveContractSample>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SaveContractSample.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'expected_revision',
    'sample',
  };
}


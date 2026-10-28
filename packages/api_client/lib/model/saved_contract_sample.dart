//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SavedContractSample {
  /// Returns a new [SavedContractSample] instance.
  SavedContractSample({
    required this.revision,
    required this.sample,
  });

  final int revision;

  final ContractSample sample;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SavedContractSample &&
    other.revision == revision &&
    other.sample == sample;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (revision.hashCode) +
    (sample.hashCode);

  @override
  String toString() => 'SavedContractSample[revision=$revision, sample=$sample]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'revision'] = this.revision;
      json[r'sample'] = this.sample;
    return json;
  }

  /// Clones this instance of [SavedContractSample] and returns a new one where some of the
  /// properties have changed.
  SavedContractSample copyWith({
    int? revision,
    ContractSample? sample,
  }) => SavedContractSample(
    revision: revision ?? this.revision,
    sample: sample ?? this.sample,
  );

  /// Returns a new [SavedContractSample] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SavedContractSample? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'revision'), 'Required key "SavedContractSample[revision]" is missing from JSON.');
        assert(json[r'revision'] != null, 'Required key "SavedContractSample[revision]" has a null value in JSON.');
        assert(json.containsKey(r'sample'), 'Required key "SavedContractSample[sample]" is missing from JSON.');
        assert(json[r'sample'] != null, 'Required key "SavedContractSample[sample]" has a null value in JSON.');
        return true;
      }());

      return SavedContractSample(
        revision: mapValueOfType<int>(json, r'revision')!,
        sample: ContractSample.fromJson(json[r'sample'])!,
      );
    }
    return null;
  }

  static List<SavedContractSample> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SavedContractSample>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SavedContractSample.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SavedContractSample> mapFromJson(dynamic json) {
    final map = <String, SavedContractSample>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SavedContractSample.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SavedContractSample-objects as value to a dart map
  static Map<String, List<SavedContractSample>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SavedContractSample>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SavedContractSample.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'revision',
    'sample',
  };
}


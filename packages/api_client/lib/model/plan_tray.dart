//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PlanTray {
  /// Returns a new [PlanTray] instance.
  PlanTray({
    required this.purpose,
    this.medicines = const [],
  });

  final String purpose;

  final List<PlanMedicine> medicines;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PlanTray &&
    other.purpose == purpose &&
    _deepEquality.equals(other.medicines, medicines);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (purpose.hashCode) +
    (medicines.hashCode);

  @override
  String toString() => 'PlanTray[purpose=$purpose, medicines=$medicines]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'purpose'] = this.purpose;
      json[r'medicines'] = this.medicines;
    return json;
  }

  /// Clones this instance of [PlanTray] and returns a new one where some of the
  /// properties have changed.
  PlanTray copyWith({
    String? purpose,
    List<PlanMedicine>? medicines,
  }) => PlanTray(
    purpose: purpose ?? this.purpose,
    medicines: medicines ?? this.medicines,
  );

  /// Returns a new [PlanTray] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PlanTray? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'purpose'), 'Required key "PlanTray[purpose]" is missing from JSON.');
        assert(json[r'purpose'] != null, 'Required key "PlanTray[purpose]" has a null value in JSON.');
        assert(json.containsKey(r'medicines'), 'Required key "PlanTray[medicines]" is missing from JSON.');
        assert(json[r'medicines'] != null, 'Required key "PlanTray[medicines]" has a null value in JSON.');
        return true;
      }());

      return PlanTray(
        purpose: mapValueOfType<String>(json, r'purpose')!,
        medicines: PlanMedicine.listFromJson(json[r'medicines']),
      );
    }
    return null;
  }

  static List<PlanTray> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PlanTray>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PlanTray.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PlanTray> mapFromJson(dynamic json) {
    final map = <String, PlanTray>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PlanTray.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PlanTray-objects as value to a dart map
  static Map<String, List<PlanTray>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PlanTray>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PlanTray.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'purpose',
    'medicines',
  };
}


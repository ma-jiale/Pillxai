//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class DoseAmounts {
  /// Returns a new [DoseAmounts] instance.
  DoseAmounts({
    required this.morning,
    required this.noon,
    required this.evening,
    required this.night,
  });

  final String morning;

  final String noon;

  final String evening;

  final String night;

  @override
  bool operator ==(Object other) => identical(this, other) || other is DoseAmounts &&
    other.morning == morning &&
    other.noon == noon &&
    other.evening == evening &&
    other.night == night;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (morning.hashCode) +
    (noon.hashCode) +
    (evening.hashCode) +
    (night.hashCode);

  @override
  String toString() => 'DoseAmounts[morning=$morning, noon=$noon, evening=$evening, night=$night]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'morning'] = this.morning;
      json[r'noon'] = this.noon;
      json[r'evening'] = this.evening;
      json[r'night'] = this.night;
    return json;
  }

  /// Clones this instance of [DoseAmounts] and returns a new one where some of the
  /// properties have changed.
  DoseAmounts copyWith({
    String? morning,
    String? noon,
    String? evening,
    String? night,
  }) => DoseAmounts(
    morning: morning ?? this.morning,
    noon: noon ?? this.noon,
    evening: evening ?? this.evening,
    night: night ?? this.night,
  );

  /// Returns a new [DoseAmounts] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static DoseAmounts? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'morning'), 'Required key "DoseAmounts[morning]" is missing from JSON.');
        assert(json[r'morning'] != null, 'Required key "DoseAmounts[morning]" has a null value in JSON.');
        assert(json.containsKey(r'noon'), 'Required key "DoseAmounts[noon]" is missing from JSON.');
        assert(json[r'noon'] != null, 'Required key "DoseAmounts[noon]" has a null value in JSON.');
        assert(json.containsKey(r'evening'), 'Required key "DoseAmounts[evening]" is missing from JSON.');
        assert(json[r'evening'] != null, 'Required key "DoseAmounts[evening]" has a null value in JSON.');
        assert(json.containsKey(r'night'), 'Required key "DoseAmounts[night]" is missing from JSON.');
        assert(json[r'night'] != null, 'Required key "DoseAmounts[night]" has a null value in JSON.');
        return true;
      }());

      return DoseAmounts(
        morning: mapValueOfType<String>(json, r'morning')!,
        noon: mapValueOfType<String>(json, r'noon')!,
        evening: mapValueOfType<String>(json, r'evening')!,
        night: mapValueOfType<String>(json, r'night')!,
      );
    }
    return null;
  }

  static List<DoseAmounts> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DoseAmounts>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DoseAmounts.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, DoseAmounts> mapFromJson(dynamic json) {
    final map = <String, DoseAmounts>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = DoseAmounts.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of DoseAmounts-objects as value to a dart map
  static Map<String, List<DoseAmounts>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<DoseAmounts>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = DoseAmounts.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'morning',
    'noon',
    'evening',
    'night',
  };
}


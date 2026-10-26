//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PlanMedicine {
  /// Returns a new [PlanMedicine] instance.
  PlanMedicine({
    required this.prescription,
    this.particles = const [],
    required this.totalParticles,
    required this.originalUnits,
  });

  final PrescriptionView prescription;

  final List<List<int>> particles;

  final int totalParticles;

  final String originalUnits;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PlanMedicine &&
    other.prescription == prescription &&
    _deepEquality.equals(other.particles, particles) &&
    other.totalParticles == totalParticles &&
    other.originalUnits == originalUnits;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (prescription.hashCode) +
    (particles.hashCode) +
    (totalParticles.hashCode) +
    (originalUnits.hashCode);

  @override
  String toString() => 'PlanMedicine[prescription=$prescription, particles=$particles, totalParticles=$totalParticles, originalUnits=$originalUnits]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'prescription'] = this.prescription;
      json[r'particles'] = this.particles;
      json[r'total_particles'] = this.totalParticles;
      json[r'original_units'] = this.originalUnits;
    return json;
  }

  /// Clones this instance of [PlanMedicine] and returns a new one where some of the
  /// properties have changed.
  PlanMedicine copyWith({
    PrescriptionView? prescription,
    List<List<int>>? particles,
    int? totalParticles,
    String? originalUnits,
  }) => PlanMedicine(
    prescription: prescription ?? this.prescription,
    particles: particles ?? this.particles,
    totalParticles: totalParticles ?? this.totalParticles,
    originalUnits: originalUnits ?? this.originalUnits,
  );

  /// Returns a new [PlanMedicine] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PlanMedicine? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'prescription'), 'Required key "PlanMedicine[prescription]" is missing from JSON.');
        assert(json[r'prescription'] != null, 'Required key "PlanMedicine[prescription]" has a null value in JSON.');
        assert(json.containsKey(r'particles'), 'Required key "PlanMedicine[particles]" is missing from JSON.');
        assert(json[r'particles'] != null, 'Required key "PlanMedicine[particles]" has a null value in JSON.');
        assert(json.containsKey(r'total_particles'), 'Required key "PlanMedicine[total_particles]" is missing from JSON.');
        assert(json[r'total_particles'] != null, 'Required key "PlanMedicine[total_particles]" has a null value in JSON.');
        assert(json.containsKey(r'original_units'), 'Required key "PlanMedicine[original_units]" is missing from JSON.');
        assert(json[r'original_units'] != null, 'Required key "PlanMedicine[original_units]" has a null value in JSON.');
        return true;
      }());

      return PlanMedicine(
        prescription: PrescriptionView.fromJson(json[r'prescription'])!,
        particles: json[r'particles'] is List
          ? (json[r'particles'] as List).map((e) =>
              e == null ? const <int>[] : (e as List).map((value) => value as int).toList(growable: false)
            ).toList()
          :  const [],
        totalParticles: mapValueOfType<int>(json, r'total_particles')!,
        originalUnits: mapValueOfType<String>(json, r'original_units')!,
      );
    }
    return null;
  }

  static List<PlanMedicine> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PlanMedicine>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PlanMedicine.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PlanMedicine> mapFromJson(dynamic json) {
    final map = <String, PlanMedicine>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PlanMedicine.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PlanMedicine-objects as value to a dart map
  static Map<String, List<PlanMedicine>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PlanMedicine>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PlanMedicine.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'prescription',
    'particles',
    'total_particles',
    'original_units',
  };
}


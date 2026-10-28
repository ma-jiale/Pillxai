//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PrescriptionData {
  /// Returns a new [PrescriptionData] instance.
  PrescriptionData({
    required this.medicineName,
    required this.strength,
    required this.unit,
    required this.feedForm,
    required this.doses,
    required this.mealRelation,
    required this.startDate,
    required this.endDate,
    this.stopped = false,
  });

  final String medicineName;

  final String strength;

  final DoseUnit unit;

  final FeedForm feedForm;

  final DoseAmounts doses;

  final MealRelation mealRelation;

  final DateTime startDate;

  final DateTime? endDate;

  final bool stopped;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PrescriptionData &&
    other.medicineName == medicineName &&
    other.strength == strength &&
    other.unit == unit &&
    other.feedForm == feedForm &&
    other.doses == doses &&
    other.mealRelation == mealRelation &&
    other.startDate == startDate &&
    other.endDate == endDate &&
    other.stopped == stopped;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (medicineName.hashCode) +
    (strength.hashCode) +
    (unit.hashCode) +
    (feedForm.hashCode) +
    (doses.hashCode) +
    (mealRelation.hashCode) +
    (startDate.hashCode) +
    (endDate == null ? 0 : endDate!.hashCode) +
    (stopped.hashCode);

  @override
  String toString() => 'PrescriptionData[medicineName=$medicineName, strength=$strength, unit=$unit, feedForm=$feedForm, doses=$doses, mealRelation=$mealRelation, startDate=$startDate, endDate=$endDate, stopped=$stopped]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'medicine_name'] = this.medicineName;
      json[r'strength'] = this.strength;
      json[r'unit'] = this.unit;
      json[r'feed_form'] = this.feedForm;
      json[r'doses'] = this.doses;
      json[r'meal_relation'] = this.mealRelation;
      json[r'start_date'] = _dateFormatter.format(this.startDate);
    if (this.endDate != null) {
      json[r'end_date'] = _dateFormatter.format(this.endDate!);
    } else {
      json[r'end_date'] = null;
    }
      json[r'stopped'] = this.stopped;
    return json;
  }

  /// Clones this instance of [PrescriptionData] and returns a new one where some of the
  /// properties have changed.
  PrescriptionData copyWith({
    String? medicineName,
    String? strength,
    DoseUnit? unit,
    FeedForm? feedForm,
    DoseAmounts? doses,
    MealRelation? mealRelation,
    DateTime? startDate,
    DateTime? endDate,
    bool endDateSetToNull = false,
    bool? stopped,
  }) => PrescriptionData(
    medicineName: medicineName ?? this.medicineName,
    strength: strength ?? this.strength,
    unit: unit ?? this.unit,
    feedForm: feedForm ?? this.feedForm,
    doses: doses ?? this.doses,
    mealRelation: mealRelation ?? this.mealRelation,
    startDate: startDate ?? this.startDate,
    endDate: endDateSetToNull ? null : endDate ?? this.endDate,
    stopped: stopped ?? this.stopped,
  );

  /// Returns a new [PrescriptionData] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PrescriptionData? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'medicine_name'), 'Required key "PrescriptionData[medicine_name]" is missing from JSON.');
        assert(json[r'medicine_name'] != null, 'Required key "PrescriptionData[medicine_name]" has a null value in JSON.');
        assert(json.containsKey(r'strength'), 'Required key "PrescriptionData[strength]" is missing from JSON.');
        assert(json[r'strength'] != null, 'Required key "PrescriptionData[strength]" has a null value in JSON.');
        assert(json.containsKey(r'unit'), 'Required key "PrescriptionData[unit]" is missing from JSON.');
        assert(json[r'unit'] != null, 'Required key "PrescriptionData[unit]" has a null value in JSON.');
        assert(json.containsKey(r'feed_form'), 'Required key "PrescriptionData[feed_form]" is missing from JSON.');
        assert(json[r'feed_form'] != null, 'Required key "PrescriptionData[feed_form]" has a null value in JSON.');
        assert(json.containsKey(r'doses'), 'Required key "PrescriptionData[doses]" is missing from JSON.');
        assert(json[r'doses'] != null, 'Required key "PrescriptionData[doses]" has a null value in JSON.');
        assert(json.containsKey(r'meal_relation'), 'Required key "PrescriptionData[meal_relation]" is missing from JSON.');
        assert(json[r'meal_relation'] != null, 'Required key "PrescriptionData[meal_relation]" has a null value in JSON.');
        assert(json.containsKey(r'start_date'), 'Required key "PrescriptionData[start_date]" is missing from JSON.');
        assert(json[r'start_date'] != null, 'Required key "PrescriptionData[start_date]" has a null value in JSON.');
        assert(json.containsKey(r'end_date'), 'Required key "PrescriptionData[end_date]" is missing from JSON.');
        return true;
      }());

      return PrescriptionData(
        medicineName: mapValueOfType<String>(json, r'medicine_name')!,
        strength: mapValueOfType<String>(json, r'strength')!,
        unit: DoseUnit.fromJson(json[r'unit'])!,
        feedForm: FeedForm.fromJson(json[r'feed_form'])!,
        doses: DoseAmounts.fromJson(json[r'doses'])!,
        mealRelation: MealRelation.fromJson(json[r'meal_relation'])!,
        startDate: mapDateTime(json, r'start_date', r'')!,
        endDate: mapDateTime(json, r'end_date', r''),
        stopped: mapValueOfType<bool>(json, r'stopped') ?? false,
      );
    }
    return null;
  }

  static List<PrescriptionData> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PrescriptionData>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PrescriptionData.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PrescriptionData> mapFromJson(dynamic json) {
    final map = <String, PrescriptionData>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PrescriptionData.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PrescriptionData-objects as value to a dart map
  static Map<String, List<PrescriptionData>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PrescriptionData>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PrescriptionData.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'medicine_name',
    'strength',
    'unit',
    'feed_form',
    'doses',
    'meal_relation',
    'start_date',
    'end_date',
  };
}


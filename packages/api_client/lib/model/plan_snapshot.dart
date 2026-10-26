//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PlanSnapshot {
  /// Returns a new [PlanSnapshot] instance.
  PlanSnapshot({
    required this.id,
    required this.residentId,
    required this.residentRevision,
    required this.residentName,
    required this.bed,
    required this.businessDate,
    required this.createdAt,
    required this.settings,
    required this.requestedDays,
    required this.splitMeals,
    this.dates = const [],
    this.slots = const [],
    this.sources = const [],
    this.trays = const [],
  });

  final String id;

  final String residentId;

  final int residentRevision;

  final String residentName;

  final String bed;

  final DateTime businessDate;

  final DateTime createdAt;

  final AppSettings settings;

  final int requestedDays;

  final bool splitMeals;

  final List<DateTime> dates;

  final List<String> slots;

  final List<PrescriptionView> sources;

  final List<PlanTray> trays;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PlanSnapshot &&
    other.id == id &&
    other.residentId == residentId &&
    other.residentRevision == residentRevision &&
    other.residentName == residentName &&
    other.bed == bed &&
    other.businessDate == businessDate &&
    other.createdAt == createdAt &&
    other.settings == settings &&
    other.requestedDays == requestedDays &&
    other.splitMeals == splitMeals &&
    _deepEquality.equals(other.dates, dates) &&
    _deepEquality.equals(other.slots, slots) &&
    _deepEquality.equals(other.sources, sources) &&
    _deepEquality.equals(other.trays, trays);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (residentId.hashCode) +
    (residentRevision.hashCode) +
    (residentName.hashCode) +
    (bed.hashCode) +
    (businessDate.hashCode) +
    (createdAt.hashCode) +
    (settings.hashCode) +
    (requestedDays.hashCode) +
    (splitMeals.hashCode) +
    (dates.hashCode) +
    (slots.hashCode) +
    (sources.hashCode) +
    (trays.hashCode);

  @override
  String toString() => 'PlanSnapshot[id=$id, residentId=$residentId, residentRevision=$residentRevision, residentName=$residentName, bed=$bed, businessDate=$businessDate, createdAt=$createdAt, settings=$settings, requestedDays=$requestedDays, splitMeals=$splitMeals, dates=$dates, slots=$slots, sources=$sources, trays=$trays]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'resident_id'] = this.residentId;
      json[r'resident_revision'] = this.residentRevision;
      json[r'resident_name'] = this.residentName;
      json[r'bed'] = this.bed;
      json[r'business_date'] = _dateFormatter.format(this.businessDate);
      json[r'created_at'] = this.createdAt.toUtc().toIso8601String();
      json[r'settings'] = this.settings;
      json[r'requested_days'] = this.requestedDays;
      json[r'split_meals'] = this.splitMeals;
      json[r'dates'] = this.dates;
      json[r'slots'] = this.slots;
      json[r'sources'] = this.sources;
      json[r'trays'] = this.trays;
    return json;
  }

  /// Clones this instance of [PlanSnapshot] and returns a new one where some of the
  /// properties have changed.
  PlanSnapshot copyWith({
    String? id,
    String? residentId,
    int? residentRevision,
    String? residentName,
    String? bed,
    DateTime? businessDate,
    DateTime? createdAt,
    AppSettings? settings,
    int? requestedDays,
    bool? splitMeals,
    List<DateTime>? dates,
    List<String>? slots,
    List<PrescriptionView>? sources,
    List<PlanTray>? trays,
  }) => PlanSnapshot(
    id: id ?? this.id,
    residentId: residentId ?? this.residentId,
    residentRevision: residentRevision ?? this.residentRevision,
    residentName: residentName ?? this.residentName,
    bed: bed ?? this.bed,
    businessDate: businessDate ?? this.businessDate,
    createdAt: createdAt ?? this.createdAt,
    settings: settings ?? this.settings,
    requestedDays: requestedDays ?? this.requestedDays,
    splitMeals: splitMeals ?? this.splitMeals,
    dates: dates ?? this.dates,
    slots: slots ?? this.slots,
    sources: sources ?? this.sources,
    trays: trays ?? this.trays,
  );

  /// Returns a new [PlanSnapshot] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PlanSnapshot? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'), 'Required key "PlanSnapshot[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "PlanSnapshot[id]" has a null value in JSON.');
        assert(json.containsKey(r'resident_id'), 'Required key "PlanSnapshot[resident_id]" is missing from JSON.');
        assert(json[r'resident_id'] != null, 'Required key "PlanSnapshot[resident_id]" has a null value in JSON.');
        assert(json.containsKey(r'resident_revision'), 'Required key "PlanSnapshot[resident_revision]" is missing from JSON.');
        assert(json[r'resident_revision'] != null, 'Required key "PlanSnapshot[resident_revision]" has a null value in JSON.');
        assert(json.containsKey(r'resident_name'), 'Required key "PlanSnapshot[resident_name]" is missing from JSON.');
        assert(json[r'resident_name'] != null, 'Required key "PlanSnapshot[resident_name]" has a null value in JSON.');
        assert(json.containsKey(r'bed'), 'Required key "PlanSnapshot[bed]" is missing from JSON.');
        assert(json[r'bed'] != null, 'Required key "PlanSnapshot[bed]" has a null value in JSON.');
        assert(json.containsKey(r'business_date'), 'Required key "PlanSnapshot[business_date]" is missing from JSON.');
        assert(json[r'business_date'] != null, 'Required key "PlanSnapshot[business_date]" has a null value in JSON.');
        assert(json.containsKey(r'created_at'), 'Required key "PlanSnapshot[created_at]" is missing from JSON.');
        assert(json[r'created_at'] != null, 'Required key "PlanSnapshot[created_at]" has a null value in JSON.');
        assert(json.containsKey(r'settings'), 'Required key "PlanSnapshot[settings]" is missing from JSON.');
        assert(json[r'settings'] != null, 'Required key "PlanSnapshot[settings]" has a null value in JSON.');
        assert(json.containsKey(r'requested_days'), 'Required key "PlanSnapshot[requested_days]" is missing from JSON.');
        assert(json[r'requested_days'] != null, 'Required key "PlanSnapshot[requested_days]" has a null value in JSON.');
        assert(json.containsKey(r'split_meals'), 'Required key "PlanSnapshot[split_meals]" is missing from JSON.');
        assert(json[r'split_meals'] != null, 'Required key "PlanSnapshot[split_meals]" has a null value in JSON.');
        assert(json.containsKey(r'dates'), 'Required key "PlanSnapshot[dates]" is missing from JSON.');
        assert(json[r'dates'] != null, 'Required key "PlanSnapshot[dates]" has a null value in JSON.');
        assert(json.containsKey(r'slots'), 'Required key "PlanSnapshot[slots]" is missing from JSON.');
        assert(json[r'slots'] != null, 'Required key "PlanSnapshot[slots]" has a null value in JSON.');
        assert(json.containsKey(r'sources'), 'Required key "PlanSnapshot[sources]" is missing from JSON.');
        assert(json[r'sources'] != null, 'Required key "PlanSnapshot[sources]" has a null value in JSON.');
        assert(json.containsKey(r'trays'), 'Required key "PlanSnapshot[trays]" is missing from JSON.');
        assert(json[r'trays'] != null, 'Required key "PlanSnapshot[trays]" has a null value in JSON.');
        return true;
      }());

      return PlanSnapshot(
        id: mapValueOfType<String>(json, r'id')!,
        residentId: mapValueOfType<String>(json, r'resident_id')!,
        residentRevision: mapValueOfType<int>(json, r'resident_revision')!,
        residentName: mapValueOfType<String>(json, r'resident_name')!,
        bed: mapValueOfType<String>(json, r'bed')!,
        businessDate: mapDateTime(json, r'business_date', r'')!,
        createdAt: mapDateTime(json, r'created_at', r'')!,
        settings: AppSettings.fromJson(json[r'settings'])!,
        requestedDays: mapValueOfType<int>(json, r'requested_days')!,
        splitMeals: mapValueOfType<bool>(json, r'split_meals')!,
        dates: (json[r'dates'] as List).map((value) => DateTime.parse(value as String)).toList(),
        slots: json[r'slots'] is Iterable
            ? (json[r'slots'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        sources: PrescriptionView.listFromJson(json[r'sources']),
        trays: PlanTray.listFromJson(json[r'trays']),
      );
    }
    return null;
  }

  static List<PlanSnapshot> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PlanSnapshot>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PlanSnapshot.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PlanSnapshot> mapFromJson(dynamic json) {
    final map = <String, PlanSnapshot>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PlanSnapshot.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PlanSnapshot-objects as value to a dart map
  static Map<String, List<PlanSnapshot>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PlanSnapshot>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PlanSnapshot.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'resident_id',
    'resident_revision',
    'resident_name',
    'bed',
    'business_date',
    'created_at',
    'settings',
    'requested_days',
    'split_meals',
    'dates',
    'slots',
    'sources',
    'trays',
  };
}


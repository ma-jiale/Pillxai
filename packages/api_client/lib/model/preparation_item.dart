//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PreparationItem {
  /// Returns a new [PreparationItem] instance.
  PreparationItem({
    required this.residentId,
    required this.name,
    required this.bed,
    required this.early,
    required this.medicineCount,
    this.dates = const [],
    this.coverageThrough,
    this.issue,
  });

  final String residentId;

  final String name;

  final String bed;

  final bool early;

  final int medicineCount;

  final List<DateTime> dates;

  final DateTime? coverageThrough;

  final String? issue;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PreparationItem &&
    other.residentId == residentId &&
    other.name == name &&
    other.bed == bed &&
    other.early == early &&
    other.medicineCount == medicineCount &&
    _deepEquality.equals(other.dates, dates) &&
    other.coverageThrough == coverageThrough &&
    other.issue == issue;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (residentId.hashCode) +
    (name.hashCode) +
    (bed.hashCode) +
    (early.hashCode) +
    (medicineCount.hashCode) +
    (dates.hashCode) +
    (coverageThrough == null ? 0 : coverageThrough!.hashCode) +
    (issue == null ? 0 : issue!.hashCode);

  @override
  String toString() => 'PreparationItem[residentId=$residentId, name=$name, bed=$bed, early=$early, medicineCount=$medicineCount, dates=$dates, coverageThrough=$coverageThrough, issue=$issue]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'resident_id'] = this.residentId;
      json[r'name'] = this.name;
      json[r'bed'] = this.bed;
      json[r'early'] = this.early;
      json[r'medicine_count'] = this.medicineCount;
      json[r'dates'] = this.dates.map((value) => value.toIso8601String().substring(0, 10)).toList();
    if (this.coverageThrough != null) {
      json[r'coverage_through'] = _dateFormatter.format(this.coverageThrough!);
    } else {
      json[r'coverage_through'] = null;
    }
    if (this.issue != null) {
      json[r'issue'] = this.issue;
    } else {
      json[r'issue'] = null;
    }
    return json;
  }

  /// Clones this instance of [PreparationItem] and returns a new one where some of the
  /// properties have changed.
  PreparationItem copyWith({
    String? residentId,
    String? name,
    String? bed,
    bool? early,
    int? medicineCount,
    List<DateTime>? dates,
    DateTime? coverageThrough,
    bool coverageThroughSetToNull = false,
    String? issue,
    bool issueSetToNull = false,
  }) => PreparationItem(
    residentId: residentId ?? this.residentId,
    name: name ?? this.name,
    bed: bed ?? this.bed,
    early: early ?? this.early,
    medicineCount: medicineCount ?? this.medicineCount,
    dates: dates ?? this.dates,
    coverageThrough: coverageThroughSetToNull ? null : coverageThrough ?? this.coverageThrough,
    issue: issueSetToNull ? null : issue ?? this.issue,
  );

  /// Returns a new [PreparationItem] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PreparationItem? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'resident_id'), 'Required key "PreparationItem[resident_id]" is missing from JSON.');
        assert(json[r'resident_id'] != null, 'Required key "PreparationItem[resident_id]" has a null value in JSON.');
        assert(json.containsKey(r'name'), 'Required key "PreparationItem[name]" is missing from JSON.');
        assert(json[r'name'] != null, 'Required key "PreparationItem[name]" has a null value in JSON.');
        assert(json.containsKey(r'bed'), 'Required key "PreparationItem[bed]" is missing from JSON.');
        assert(json[r'bed'] != null, 'Required key "PreparationItem[bed]" has a null value in JSON.');
        assert(json.containsKey(r'early'), 'Required key "PreparationItem[early]" is missing from JSON.');
        assert(json[r'early'] != null, 'Required key "PreparationItem[early]" has a null value in JSON.');
        assert(json.containsKey(r'medicine_count'), 'Required key "PreparationItem[medicine_count]" is missing from JSON.');
        assert(json[r'medicine_count'] != null, 'Required key "PreparationItem[medicine_count]" has a null value in JSON.');
        assert(json.containsKey(r'dates'), 'Required key "PreparationItem[dates]" is missing from JSON.');
        assert(json[r'dates'] != null, 'Required key "PreparationItem[dates]" has a null value in JSON.');
        return true;
      }());

      return PreparationItem(
        residentId: mapValueOfType<String>(json, r'resident_id')!,
        name: mapValueOfType<String>(json, r'name')!,
        bed: mapValueOfType<String>(json, r'bed')!,
        early: mapValueOfType<bool>(json, r'early')!,
        medicineCount: mapValueOfType<int>(json, r'medicine_count')!,
        dates: (json[r'dates'] as List).map((value) => DateTime.parse(value as String)).toList(),
        coverageThrough: mapDateTime(json, r'coverage_through', r''),
        issue: mapValueOfType<String>(json, r'issue'),
      );
    }
    return null;
  }

  static List<PreparationItem> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PreparationItem>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PreparationItem.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PreparationItem> mapFromJson(dynamic json) {
    final map = <String, PreparationItem>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PreparationItem.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PreparationItem-objects as value to a dart map
  static Map<String, List<PreparationItem>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PreparationItem>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PreparationItem.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'resident_id',
    'name',
    'bed',
    'early',
    'medicine_count',
    'dates',
  };
}


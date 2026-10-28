//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ContractSample {
  /// Returns a new [ContractSample] instance.
  ContractSample({
    required this.sampleId,
    required this.prescriptionVersion,
    required this.startDate,
    required this.endDate,
    required this.observedAt,
    required this.feedForm,
    required this.originalTablets,
    required this.particles,
    required this.note,
  });

  final String sampleId;

  /// Minimum value: 1
  final int prescriptionVersion;

  final DateTime startDate;

  final DateTime? endDate;

  final DateTime observedAt;

  final FeedForm feedForm;

  final String originalTablets;

  /// Minimum value: 1
  /// Maximum value: 255
  final int particles;

  final String? note;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ContractSample &&
    other.sampleId == sampleId &&
    other.prescriptionVersion == prescriptionVersion &&
    other.startDate == startDate &&
    other.endDate == endDate &&
    other.observedAt == observedAt &&
    other.feedForm == feedForm &&
    other.originalTablets == originalTablets &&
    other.particles == particles &&
    other.note == note;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (sampleId.hashCode) +
    (prescriptionVersion.hashCode) +
    (startDate.hashCode) +
    (endDate == null ? 0 : endDate!.hashCode) +
    (observedAt.hashCode) +
    (feedForm.hashCode) +
    (originalTablets.hashCode) +
    (particles.hashCode) +
    (note == null ? 0 : note!.hashCode);

  @override
  String toString() => 'ContractSample[sampleId=$sampleId, prescriptionVersion=$prescriptionVersion, startDate=$startDate, endDate=$endDate, observedAt=$observedAt, feedForm=$feedForm, originalTablets=$originalTablets, particles=$particles, note=$note]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'sample_id'] = this.sampleId;
      json[r'prescription_version'] = this.prescriptionVersion;
      json[r'start_date'] = _dateFormatter.format(this.startDate);
    if (this.endDate != null) {
      json[r'end_date'] = _dateFormatter.format(this.endDate!);
    } else {
      json[r'end_date'] = null;
    }
      json[r'observed_at'] = this.observedAt.toUtc().toIso8601String();
      json[r'feed_form'] = this.feedForm;
      json[r'original_tablets'] = this.originalTablets;
      json[r'particles'] = this.particles;
    if (this.note != null) {
      json[r'note'] = this.note;
    } else {
      json[r'note'] = null;
    }
    return json;
  }

  /// Clones this instance of [ContractSample] and returns a new one where some of the
  /// properties have changed.
  ContractSample copyWith({
    String? sampleId,
    int? prescriptionVersion,
    DateTime? startDate,
    DateTime? endDate,
    bool endDateSetToNull = false,
    DateTime? observedAt,
    FeedForm? feedForm,
    String? originalTablets,
    int? particles,
    String? note,
    bool noteSetToNull = false,
  }) => ContractSample(
    sampleId: sampleId ?? this.sampleId,
    prescriptionVersion: prescriptionVersion ?? this.prescriptionVersion,
    startDate: startDate ?? this.startDate,
    endDate: endDateSetToNull ? null : endDate ?? this.endDate,
    observedAt: observedAt ?? this.observedAt,
    feedForm: feedForm ?? this.feedForm,
    originalTablets: originalTablets ?? this.originalTablets,
    particles: particles ?? this.particles,
    note: noteSetToNull ? null : note ?? this.note,
  );

  /// Returns a new [ContractSample] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ContractSample? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'sample_id'), 'Required key "ContractSample[sample_id]" is missing from JSON.');
        assert(json[r'sample_id'] != null, 'Required key "ContractSample[sample_id]" has a null value in JSON.');
        assert(json.containsKey(r'prescription_version'), 'Required key "ContractSample[prescription_version]" is missing from JSON.');
        assert(json[r'prescription_version'] != null, 'Required key "ContractSample[prescription_version]" has a null value in JSON.');
        assert(json.containsKey(r'start_date'), 'Required key "ContractSample[start_date]" is missing from JSON.');
        assert(json[r'start_date'] != null, 'Required key "ContractSample[start_date]" has a null value in JSON.');
        assert(json.containsKey(r'end_date'), 'Required key "ContractSample[end_date]" is missing from JSON.');
        assert(json.containsKey(r'observed_at'), 'Required key "ContractSample[observed_at]" is missing from JSON.');
        assert(json[r'observed_at'] != null, 'Required key "ContractSample[observed_at]" has a null value in JSON.');
        assert(json.containsKey(r'feed_form'), 'Required key "ContractSample[feed_form]" is missing from JSON.');
        assert(json[r'feed_form'] != null, 'Required key "ContractSample[feed_form]" has a null value in JSON.');
        assert(json.containsKey(r'original_tablets'), 'Required key "ContractSample[original_tablets]" is missing from JSON.');
        assert(json[r'original_tablets'] != null, 'Required key "ContractSample[original_tablets]" has a null value in JSON.');
        assert(json.containsKey(r'particles'), 'Required key "ContractSample[particles]" is missing from JSON.');
        assert(json[r'particles'] != null, 'Required key "ContractSample[particles]" has a null value in JSON.');
        assert(json.containsKey(r'note'), 'Required key "ContractSample[note]" is missing from JSON.');
        return true;
      }());

      return ContractSample(
        sampleId: mapValueOfType<String>(json, r'sample_id')!,
        prescriptionVersion: mapValueOfType<int>(json, r'prescription_version')!,
        startDate: mapDateTime(json, r'start_date', r'')!,
        endDate: mapDateTime(json, r'end_date', r''),
        observedAt: mapDateTime(json, r'observed_at', r'')!,
        feedForm: FeedForm.fromJson(json[r'feed_form'])!,
        originalTablets: mapValueOfType<String>(json, r'original_tablets')!,
        particles: mapValueOfType<int>(json, r'particles')!,
        note: mapValueOfType<String>(json, r'note'),
      );
    }
    return null;
  }

  static List<ContractSample> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ContractSample>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ContractSample.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ContractSample> mapFromJson(dynamic json) {
    final map = <String, ContractSample>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ContractSample.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ContractSample-objects as value to a dart map
  static Map<String, List<ContractSample>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ContractSample>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ContractSample.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'sample_id',
    'prescription_version',
    'start_date',
    'end_date',
    'observed_at',
    'feed_form',
    'original_tablets',
    'particles',
    'note',
  };
}


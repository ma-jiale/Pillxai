//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class LearningResult {
  /// Returns a new [LearningResult] instance.
  LearningResult({
    required this.batch,
    required this.status,
    required this.message,
    required this.baseRevision,
    this.appliedRevision,
    this.median,
    this.turntable,
    this.gate,
    required this.evidence,
  });

  final int batch;

  final String status;

  final String message;

  final int baseRevision;

  final int? appliedRevision;

  final num? median;

  final num? turntable;

  final num? gate;

  final LearningEvidence evidence;

  @override
  bool operator ==(Object other) => identical(this, other) || other is LearningResult &&
    other.batch == batch &&
    other.status == status &&
    other.message == message &&
    other.baseRevision == baseRevision &&
    other.appliedRevision == appliedRevision &&
    other.median == median &&
    other.turntable == turntable &&
    other.gate == gate &&
    other.evidence == evidence;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (batch.hashCode) +
    (status.hashCode) +
    (message.hashCode) +
    (baseRevision.hashCode) +
    (appliedRevision == null ? 0 : appliedRevision!.hashCode) +
    (median == null ? 0 : median!.hashCode) +
    (turntable == null ? 0 : turntable!.hashCode) +
    (gate == null ? 0 : gate!.hashCode) +
    (evidence.hashCode);

  @override
  String toString() => 'LearningResult[batch=$batch, status=$status, message=$message, baseRevision=$baseRevision, appliedRevision=$appliedRevision, median=$median, turntable=$turntable, gate=$gate, evidence=$evidence]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'batch'] = this.batch;
      json[r'status'] = this.status;
      json[r'message'] = this.message;
      json[r'base_revision'] = this.baseRevision;
    if (this.appliedRevision != null) {
      json[r'applied_revision'] = this.appliedRevision;
    } else {
      json[r'applied_revision'] = null;
    }
    if (this.median != null) {
      json[r'median'] = this.median;
    } else {
      json[r'median'] = null;
    }
    if (this.turntable != null) {
      json[r'turntable'] = this.turntable;
    } else {
      json[r'turntable'] = null;
    }
    if (this.gate != null) {
      json[r'gate'] = this.gate;
    } else {
      json[r'gate'] = null;
    }
      json[r'evidence'] = this.evidence;
    return json;
  }

  /// Clones this instance of [LearningResult] and returns a new one where some of the
  /// properties have changed.
  LearningResult copyWith({
    int? batch,
    String? status,
    String? message,
    int? baseRevision,
    int? appliedRevision,
    bool appliedRevisionSetToNull = false,
    num? median,
    bool medianSetToNull = false,
    num? turntable,
    bool turntableSetToNull = false,
    num? gate,
    bool gateSetToNull = false,
    LearningEvidence? evidence,
  }) => LearningResult(
    batch: batch ?? this.batch,
    status: status ?? this.status,
    message: message ?? this.message,
    baseRevision: baseRevision ?? this.baseRevision,
    appliedRevision: appliedRevisionSetToNull ? null : appliedRevision ?? this.appliedRevision,
    median: medianSetToNull ? null : median ?? this.median,
    turntable: turntableSetToNull ? null : turntable ?? this.turntable,
    gate: gateSetToNull ? null : gate ?? this.gate,
    evidence: evidence ?? this.evidence,
  );

  /// Returns a new [LearningResult] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static LearningResult? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'batch'), 'Required key "LearningResult[batch]" is missing from JSON.');
        assert(json[r'batch'] != null, 'Required key "LearningResult[batch]" has a null value in JSON.');
        assert(json.containsKey(r'status'), 'Required key "LearningResult[status]" is missing from JSON.');
        assert(json[r'status'] != null, 'Required key "LearningResult[status]" has a null value in JSON.');
        assert(json.containsKey(r'message'), 'Required key "LearningResult[message]" is missing from JSON.');
        assert(json[r'message'] != null, 'Required key "LearningResult[message]" has a null value in JSON.');
        assert(json.containsKey(r'base_revision'), 'Required key "LearningResult[base_revision]" is missing from JSON.');
        assert(json[r'base_revision'] != null, 'Required key "LearningResult[base_revision]" has a null value in JSON.');
        assert(json.containsKey(r'evidence'), 'Required key "LearningResult[evidence]" is missing from JSON.');
        assert(json[r'evidence'] != null, 'Required key "LearningResult[evidence]" has a null value in JSON.');
        return true;
      }());

      return LearningResult(
        batch: mapValueOfType<int>(json, r'batch')!,
        status: mapValueOfType<String>(json, r'status')!,
        message: mapValueOfType<String>(json, r'message')!,
        baseRevision: mapValueOfType<int>(json, r'base_revision')!,
        appliedRevision: mapValueOfType<int>(json, r'applied_revision'),
        median: json[r'median'] == null
            ? null
            : num.parse('${json[r'median']}'),
        turntable: json[r'turntable'] == null
            ? null
            : num.parse('${json[r'turntable']}'),
        gate: json[r'gate'] == null
            ? null
            : num.parse('${json[r'gate']}'),
        evidence: LearningEvidence.fromJson(json[r'evidence'])!,
      );
    }
    return null;
  }

  static List<LearningResult> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <LearningResult>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = LearningResult.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, LearningResult> mapFromJson(dynamic json) {
    final map = <String, LearningResult>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = LearningResult.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of LearningResult-objects as value to a dart map
  static Map<String, List<LearningResult>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<LearningResult>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = LearningResult.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'batch',
    'status',
    'message',
    'base_revision',
    'evidence',
  };
}


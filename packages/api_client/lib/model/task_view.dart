//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TaskView {
  /// Returns a new [TaskView] instance.
  TaskView({
    required this.id,
    required this.planId,
    required this.deviceId,
    required this.terminalId,
    required this.ownerId,
    required this.revision,
    required this.state,
    required this.plan,
    required this.device,
    this.labels = const [],
    this.recognitionBindings = const [],
    this.batches = const [],
    required this.sequence,
    this.completedBatches = const [],
    this.counts = const [],
    required this.startedAt,
    required this.updatedAt,
    this.learningResults = const [],
  });

  final String id;

  final String planId;

  final String deviceId;

  final String terminalId;

  final String ownerId;

  final int revision;

  final TaskState state;

  final PlanSnapshot plan;

  final DeviceView device;

  final List<String> labels;

  final List<RecognitionBinding> recognitionBindings;

  final List<BatchPlan> batches;

  final int sequence;

  final List<int> completedBatches;

  final List<int> counts;

  final DateTime? startedAt;

  final DateTime updatedAt;

  final List<LearningResult> learningResults;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TaskView &&
    other.id == id &&
    other.planId == planId &&
    other.deviceId == deviceId &&
    other.terminalId == terminalId &&
    other.ownerId == ownerId &&
    other.revision == revision &&
    other.state == state &&
    other.plan == plan &&
    other.device == device &&
    _deepEquality.equals(other.labels, labels) &&
    _deepEquality.equals(other.recognitionBindings, recognitionBindings) &&
    _deepEquality.equals(other.batches, batches) &&
    other.sequence == sequence &&
    _deepEquality.equals(other.completedBatches, completedBatches) &&
    _deepEquality.equals(other.counts, counts) &&
    other.startedAt == startedAt &&
    other.updatedAt == updatedAt &&
    _deepEquality.equals(other.learningResults, learningResults);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (planId.hashCode) +
    (deviceId.hashCode) +
    (terminalId.hashCode) +
    (ownerId.hashCode) +
    (revision.hashCode) +
    (state.hashCode) +
    (plan.hashCode) +
    (device.hashCode) +
    (labels.hashCode) +
    (recognitionBindings.hashCode) +
    (batches.hashCode) +
    (sequence.hashCode) +
    (completedBatches.hashCode) +
    (counts.hashCode) +
    (startedAt == null ? 0 : startedAt!.hashCode) +
    (updatedAt.hashCode) +
    (learningResults.hashCode);

  @override
  String toString() => 'TaskView[id=$id, planId=$planId, deviceId=$deviceId, terminalId=$terminalId, ownerId=$ownerId, revision=$revision, state=$state, plan=$plan, device=$device, labels=$labels, recognitionBindings=$recognitionBindings, batches=$batches, sequence=$sequence, completedBatches=$completedBatches, counts=$counts, startedAt=$startedAt, updatedAt=$updatedAt, learningResults=$learningResults]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'plan_id'] = this.planId;
      json[r'device_id'] = this.deviceId;
      json[r'terminal_id'] = this.terminalId;
      json[r'owner_id'] = this.ownerId;
      json[r'revision'] = this.revision;
      json[r'state'] = this.state;
      json[r'plan'] = this.plan;
      json[r'device'] = this.device;
      json[r'labels'] = this.labels;
      json[r'recognition_bindings'] = this.recognitionBindings;
      json[r'batches'] = this.batches;
      json[r'sequence'] = this.sequence;
      json[r'completed_batches'] = this.completedBatches;
      json[r'counts'] = this.counts;
    if (this.startedAt != null) {
      json[r'started_at'] = this.startedAt!.toUtc().toIso8601String();
    } else {
      json[r'started_at'] = null;
    }
      json[r'updated_at'] = this.updatedAt.toUtc().toIso8601String();
      json[r'learning_results'] = this.learningResults;
    return json;
  }

  /// Clones this instance of [TaskView] and returns a new one where some of the
  /// properties have changed.
  TaskView copyWith({
    String? id,
    String? planId,
    String? deviceId,
    String? terminalId,
    String? ownerId,
    int? revision,
    TaskState? state,
    PlanSnapshot? plan,
    DeviceView? device,
    List<String>? labels,
    List<RecognitionBinding>? recognitionBindings,
    List<BatchPlan>? batches,
    int? sequence,
    List<int>? completedBatches,
    List<int>? counts,
    DateTime? startedAt,
    bool startedAtSetToNull = false,
    DateTime? updatedAt,
    List<LearningResult>? learningResults,
  }) => TaskView(
    id: id ?? this.id,
    planId: planId ?? this.planId,
    deviceId: deviceId ?? this.deviceId,
    terminalId: terminalId ?? this.terminalId,
    ownerId: ownerId ?? this.ownerId,
    revision: revision ?? this.revision,
    state: state ?? this.state,
    plan: plan ?? this.plan,
    device: device ?? this.device,
    labels: labels ?? this.labels,
    recognitionBindings: recognitionBindings ?? this.recognitionBindings,
    batches: batches ?? this.batches,
    sequence: sequence ?? this.sequence,
    completedBatches: completedBatches ?? this.completedBatches,
    counts: counts ?? this.counts,
    startedAt: startedAtSetToNull ? null : startedAt ?? this.startedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    learningResults: learningResults ?? this.learningResults,
  );

  /// Returns a new [TaskView] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TaskView? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'), 'Required key "TaskView[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "TaskView[id]" has a null value in JSON.');
        assert(json.containsKey(r'plan_id'), 'Required key "TaskView[plan_id]" is missing from JSON.');
        assert(json[r'plan_id'] != null, 'Required key "TaskView[plan_id]" has a null value in JSON.');
        assert(json.containsKey(r'device_id'), 'Required key "TaskView[device_id]" is missing from JSON.');
        assert(json[r'device_id'] != null, 'Required key "TaskView[device_id]" has a null value in JSON.');
        assert(json.containsKey(r'terminal_id'), 'Required key "TaskView[terminal_id]" is missing from JSON.');
        assert(json[r'terminal_id'] != null, 'Required key "TaskView[terminal_id]" has a null value in JSON.');
        assert(json.containsKey(r'owner_id'), 'Required key "TaskView[owner_id]" is missing from JSON.');
        assert(json[r'owner_id'] != null, 'Required key "TaskView[owner_id]" has a null value in JSON.');
        assert(json.containsKey(r'revision'), 'Required key "TaskView[revision]" is missing from JSON.');
        assert(json[r'revision'] != null, 'Required key "TaskView[revision]" has a null value in JSON.');
        assert(json.containsKey(r'state'), 'Required key "TaskView[state]" is missing from JSON.');
        assert(json[r'state'] != null, 'Required key "TaskView[state]" has a null value in JSON.');
        assert(json.containsKey(r'plan'), 'Required key "TaskView[plan]" is missing from JSON.');
        assert(json[r'plan'] != null, 'Required key "TaskView[plan]" has a null value in JSON.');
        assert(json.containsKey(r'device'), 'Required key "TaskView[device]" is missing from JSON.');
        assert(json[r'device'] != null, 'Required key "TaskView[device]" has a null value in JSON.');
        assert(json.containsKey(r'labels'), 'Required key "TaskView[labels]" is missing from JSON.');
        assert(json[r'labels'] != null, 'Required key "TaskView[labels]" has a null value in JSON.');
        assert(json.containsKey(r'batches'), 'Required key "TaskView[batches]" is missing from JSON.');
        assert(json[r'batches'] != null, 'Required key "TaskView[batches]" has a null value in JSON.');
        assert(json.containsKey(r'sequence'), 'Required key "TaskView[sequence]" is missing from JSON.');
        assert(json[r'sequence'] != null, 'Required key "TaskView[sequence]" has a null value in JSON.');
        assert(json.containsKey(r'completed_batches'), 'Required key "TaskView[completed_batches]" is missing from JSON.');
        assert(json[r'completed_batches'] != null, 'Required key "TaskView[completed_batches]" has a null value in JSON.');
        assert(json.containsKey(r'counts'), 'Required key "TaskView[counts]" is missing from JSON.');
        assert(json[r'counts'] != null, 'Required key "TaskView[counts]" has a null value in JSON.');
        assert(json.containsKey(r'started_at'), 'Required key "TaskView[started_at]" is missing from JSON.');
        assert(json.containsKey(r'updated_at'), 'Required key "TaskView[updated_at]" is missing from JSON.');
        assert(json[r'updated_at'] != null, 'Required key "TaskView[updated_at]" has a null value in JSON.');
        return true;
      }());

      return TaskView(
        id: mapValueOfType<String>(json, r'id')!,
        planId: mapValueOfType<String>(json, r'plan_id')!,
        deviceId: mapValueOfType<String>(json, r'device_id')!,
        terminalId: mapValueOfType<String>(json, r'terminal_id')!,
        ownerId: mapValueOfType<String>(json, r'owner_id')!,
        revision: mapValueOfType<int>(json, r'revision')!,
        state: TaskState.fromJson(json[r'state'])!,
        plan: PlanSnapshot.fromJson(json[r'plan'])!,
        device: DeviceView.fromJson(json[r'device'])!,
        labels: json[r'labels'] is Iterable
            ? (json[r'labels'] as Iterable).cast<String>().toList(growable: false)
            : const [],
        recognitionBindings: RecognitionBinding.listFromJson(json[r'recognition_bindings']),
        batches: BatchPlan.listFromJson(json[r'batches']),
        sequence: mapValueOfType<int>(json, r'sequence')!,
        completedBatches: json[r'completed_batches'] is Iterable
            ? (json[r'completed_batches'] as Iterable).cast<int>().toList(growable: false)
            : const [],
        counts: json[r'counts'] is Iterable
            ? (json[r'counts'] as Iterable).cast<int>().toList(growable: false)
            : const [],
        startedAt: mapDateTime(json, r'started_at', r''),
        updatedAt: mapDateTime(json, r'updated_at', r'')!,
        learningResults: LearningResult.listFromJson(json[r'learning_results']),
      );
    }
    return null;
  }

  static List<TaskView> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TaskView>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TaskView.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TaskView> mapFromJson(dynamic json) {
    final map = <String, TaskView>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TaskView.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TaskView-objects as value to a dart map
  static Map<String, List<TaskView>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TaskView>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TaskView.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'plan_id',
    'device_id',
    'terminal_id',
    'owner_id',
    'revision',
    'state',
    'plan',
    'device',
    'labels',
    'batches',
    'sequence',
    'completed_batches',
    'counts',
    'started_at',
    'updated_at',
  };
}


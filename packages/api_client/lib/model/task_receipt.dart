//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TaskReceipt {
  /// Returns a new [TaskReceipt] instance.
  TaskReceipt({
    required this.taskId,
    required this.deleted,
  });

  final String taskId;

  final bool deleted;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TaskReceipt &&
    other.taskId == taskId &&
    other.deleted == deleted;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (taskId.hashCode) +
    (deleted.hashCode);

  @override
  String toString() => 'TaskReceipt[taskId=$taskId, deleted=$deleted]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'task_id'] = this.taskId;
      json[r'deleted'] = this.deleted;
    return json;
  }

  /// Clones this instance of [TaskReceipt] and returns a new one where some of the
  /// properties have changed.
  TaskReceipt copyWith({
    String? taskId,
    bool? deleted,
  }) => TaskReceipt(
    taskId: taskId ?? this.taskId,
    deleted: deleted ?? this.deleted,
  );

  /// Returns a new [TaskReceipt] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TaskReceipt? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'task_id'), 'Required key "TaskReceipt[task_id]" is missing from JSON.');
        assert(json[r'task_id'] != null, 'Required key "TaskReceipt[task_id]" has a null value in JSON.');
        assert(json.containsKey(r'deleted'), 'Required key "TaskReceipt[deleted]" is missing from JSON.');
        assert(json[r'deleted'] != null, 'Required key "TaskReceipt[deleted]" has a null value in JSON.');
        return true;
      }());

      return TaskReceipt(
        taskId: mapValueOfType<String>(json, r'task_id')!,
        deleted: mapValueOfType<bool>(json, r'deleted')!,
      );
    }
    return null;
  }

  static List<TaskReceipt> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TaskReceipt>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TaskReceipt.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TaskReceipt> mapFromJson(dynamic json) {
    final map = <String, TaskReceipt>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TaskReceipt.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TaskReceipt-objects as value to a dart map
  static Map<String, List<TaskReceipt>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TaskReceipt>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TaskReceipt.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'task_id',
    'deleted',
  };
}


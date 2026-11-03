//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class DiscardTask {
  /// Returns a new [DiscardTask] instance.
  DiscardTask({
    required this.terminalId,
    required this.physicalSceneSafe,
    this.reason,
  });

  final String terminalId;

  final bool physicalSceneSafe;

  final DiscardTaskReasonEnum? reason;

  @override
  bool operator ==(Object other) => identical(this, other) || other is DiscardTask &&
    other.terminalId == terminalId &&
    other.physicalSceneSafe == physicalSceneSafe &&
    other.reason == reason;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (terminalId.hashCode) +
    (physicalSceneSafe.hashCode) +
    (reason == null ? 0 : reason!.hashCode);

  @override
  String toString() => 'DiscardTask[terminalId=$terminalId, physicalSceneSafe=$physicalSceneSafe, reason=$reason]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'terminal_id'] = this.terminalId;
      json[r'physical_scene_safe'] = this.physicalSceneSafe;
    if (this.reason != null) {
      json[r'reason'] = this.reason;
    } else {
      json[r'reason'] = null;
    }
    return json;
  }

  /// Clones this instance of [DiscardTask] and returns a new one where some of the
  /// properties have changed.
  DiscardTask copyWith({
    String? terminalId,
    bool? physicalSceneSafe,
    DiscardTaskReasonEnum? reason,
    bool reasonSetToNull = false,
  }) => DiscardTask(
    terminalId: terminalId ?? this.terminalId,
    physicalSceneSafe: physicalSceneSafe ?? this.physicalSceneSafe,
    reason: reasonSetToNull ? null : reason ?? this.reason,
  );

  /// Returns a new [DiscardTask] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static DiscardTask? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'terminal_id'), 'Required key "DiscardTask[terminal_id]" is missing from JSON.');
        assert(json[r'terminal_id'] != null, 'Required key "DiscardTask[terminal_id]" has a null value in JSON.');
        assert(json.containsKey(r'physical_scene_safe'), 'Required key "DiscardTask[physical_scene_safe]" is missing from JSON.');
        assert(json[r'physical_scene_safe'] != null, 'Required key "DiscardTask[physical_scene_safe]" has a null value in JSON.');
        return true;
      }());

      return DiscardTask(
        terminalId: mapValueOfType<String>(json, r'terminal_id')!,
        physicalSceneSafe: mapValueOfType<bool>(json, r'physical_scene_safe')!,
        reason: DiscardTaskReasonEnum.fromJson(json[r'reason']),
      );
    }
    return null;
  }

  static List<DiscardTask> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DiscardTask>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DiscardTask.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, DiscardTask> mapFromJson(dynamic json) {
    final map = <String, DiscardTask>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = DiscardTask.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of DiscardTask-objects as value to a dart map
  static Map<String, List<DiscardTask>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<DiscardTask>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = DiscardTask.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'terminal_id',
    'physical_scene_safe',
  };
}


enum DiscardTaskReasonEnum {
  operator_._(r'operator'),
  deviceDisconnected._(r'device_disconnected'),
  ;

  /// Instantiate a new enum with the provided value.
  const DiscardTaskReasonEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [DiscardTaskReasonEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static DiscardTaskReasonEnum? fromJson(dynamic value) => DiscardTaskReasonEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [DiscardTaskReasonEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<DiscardTaskReasonEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DiscardTaskReasonEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DiscardTaskReasonEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [DiscardTaskReasonEnum] to String,
/// and [decode] dynamic data back to [DiscardTaskReasonEnum].
class DiscardTaskReasonEnumTypeTransformer {
  factory DiscardTaskReasonEnumTypeTransformer() => _instance ??= const DiscardTaskReasonEnumTypeTransformer._();

  const DiscardTaskReasonEnumTypeTransformer._();

  String encode(DiscardTaskReasonEnum data) => data._value;

  /// Returns the instance of [DiscardTaskReasonEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  DiscardTaskReasonEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is DiscardTaskReasonEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'operator': return DiscardTaskReasonEnum.operator_;
        case r'device_disconnected': return DiscardTaskReasonEnum.deviceDisconnected;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static DiscardTaskReasonEnumTypeTransformer? _instance;
}



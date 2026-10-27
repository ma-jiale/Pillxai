//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class DeviceConfiguration {
  /// Returns a new [DeviceConfiguration] instance.
  DeviceConfiguration({
    required this.name,
    required this.identity,
    required this.terminalId,
    required this.mode,
    this.rows = const [],
    this.reverseColumns = false,
    this.positionsVerified = false,
    this.trayPresentLine = '',
    this.trayAbsentLine = '',
    this.readyLine = '',
    this.feedbackVerified = false,
  });

  final String name;

  final String identity;

  final String terminalId;

  final DeviceMode mode;

  final List<int> rows;

  final bool reverseColumns;

  final bool positionsVerified;

  final String trayPresentLine;

  final String trayAbsentLine;

  final String readyLine;

  final bool feedbackVerified;

  @override
  bool operator ==(Object other) => identical(this, other) || other is DeviceConfiguration &&
    other.name == name &&
    other.identity == identity &&
    other.terminalId == terminalId &&
    other.mode == mode &&
    _deepEquality.equals(other.rows, rows) &&
    other.reverseColumns == reverseColumns &&
    other.positionsVerified == positionsVerified &&
    other.trayPresentLine == trayPresentLine &&
    other.trayAbsentLine == trayAbsentLine &&
    other.readyLine == readyLine &&
    other.feedbackVerified == feedbackVerified;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (name.hashCode) +
    (identity.hashCode) +
    (terminalId.hashCode) +
    (mode.hashCode) +
    (rows.hashCode) +
    (reverseColumns.hashCode) +
    (positionsVerified.hashCode) +
    (trayPresentLine.hashCode) +
    (trayAbsentLine.hashCode) +
    (readyLine.hashCode) +
    (feedbackVerified.hashCode);

  @override
  String toString() => 'DeviceConfiguration[name=$name, identity=$identity, terminalId=$terminalId, mode=$mode, rows=$rows, reverseColumns=$reverseColumns, positionsVerified=$positionsVerified, trayPresentLine=$trayPresentLine, trayAbsentLine=$trayAbsentLine, readyLine=$readyLine, feedbackVerified=$feedbackVerified]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'name'] = this.name;
      json[r'identity'] = this.identity;
      json[r'terminal_id'] = this.terminalId;
      json[r'mode'] = this.mode;
      json[r'rows'] = this.rows;
      json[r'reverse_columns'] = this.reverseColumns;
      json[r'positions_verified'] = this.positionsVerified;
      json[r'tray_present_line'] = this.trayPresentLine;
      json[r'tray_absent_line'] = this.trayAbsentLine;
      json[r'ready_line'] = this.readyLine;
      json[r'feedback_verified'] = this.feedbackVerified;
    return json;
  }

  /// Clones this instance of [DeviceConfiguration] and returns a new one where some of the
  /// properties have changed.
  DeviceConfiguration copyWith({
    String? name,
    String? identity,
    String? terminalId,
    DeviceMode? mode,
    List<int>? rows,
    bool? reverseColumns,
    bool? positionsVerified,
    String? trayPresentLine,
    String? trayAbsentLine,
    String? readyLine,
    bool? feedbackVerified,
  }) => DeviceConfiguration(
    name: name ?? this.name,
    identity: identity ?? this.identity,
    terminalId: terminalId ?? this.terminalId,
    mode: mode ?? this.mode,
    rows: rows ?? this.rows,
    reverseColumns: reverseColumns ?? this.reverseColumns,
    positionsVerified: positionsVerified ?? this.positionsVerified,
    trayPresentLine: trayPresentLine ?? this.trayPresentLine,
    trayAbsentLine: trayAbsentLine ?? this.trayAbsentLine,
    readyLine: readyLine ?? this.readyLine,
    feedbackVerified: feedbackVerified ?? this.feedbackVerified,
  );

  /// Returns a new [DeviceConfiguration] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static DeviceConfiguration? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'name'), 'Required key "DeviceConfiguration[name]" is missing from JSON.');
        assert(json[r'name'] != null, 'Required key "DeviceConfiguration[name]" has a null value in JSON.');
        assert(json.containsKey(r'identity'), 'Required key "DeviceConfiguration[identity]" is missing from JSON.');
        assert(json[r'identity'] != null, 'Required key "DeviceConfiguration[identity]" has a null value in JSON.');
        assert(json.containsKey(r'terminal_id'), 'Required key "DeviceConfiguration[terminal_id]" is missing from JSON.');
        assert(json[r'terminal_id'] != null, 'Required key "DeviceConfiguration[terminal_id]" has a null value in JSON.');
        assert(json.containsKey(r'mode'), 'Required key "DeviceConfiguration[mode]" is missing from JSON.');
        assert(json[r'mode'] != null, 'Required key "DeviceConfiguration[mode]" has a null value in JSON.');
        assert(json.containsKey(r'rows'), 'Required key "DeviceConfiguration[rows]" is missing from JSON.');
        assert(json[r'rows'] != null, 'Required key "DeviceConfiguration[rows]" has a null value in JSON.');
        return true;
      }());

      return DeviceConfiguration(
        name: mapValueOfType<String>(json, r'name')!,
        identity: mapValueOfType<String>(json, r'identity')!,
        terminalId: mapValueOfType<String>(json, r'terminal_id')!,
        mode: DeviceMode.fromJson(json[r'mode'])!,
        rows: json[r'rows'] is Iterable
            ? (json[r'rows'] as Iterable).cast<int>().toList(growable: false)
            : const [],
        reverseColumns: mapValueOfType<bool>(json, r'reverse_columns') ?? false,
        positionsVerified: mapValueOfType<bool>(json, r'positions_verified') ?? false,
        trayPresentLine: mapValueOfType<String>(json, r'tray_present_line') ?? '',
        trayAbsentLine: mapValueOfType<String>(json, r'tray_absent_line') ?? '',
        readyLine: mapValueOfType<String>(json, r'ready_line') ?? '',
        feedbackVerified: mapValueOfType<bool>(json, r'feedback_verified') ?? false,
      );
    }
    return null;
  }

  static List<DeviceConfiguration> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DeviceConfiguration>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DeviceConfiguration.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, DeviceConfiguration> mapFromJson(dynamic json) {
    final map = <String, DeviceConfiguration>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = DeviceConfiguration.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of DeviceConfiguration-objects as value to a dart map
  static Map<String, List<DeviceConfiguration>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<DeviceConfiguration>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = DeviceConfiguration.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'name',
    'identity',
    'terminal_id',
    'mode',
    'rows',
  };
}


//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ResidentView {
  /// Returns a new [ResidentView] instance.
  ResidentView({
    required this.id,
    required this.revision,
    required this.data,
    required this.updatedAt,
    required this.updatedBy,
  });

  final String id;

  final int revision;

  final ResidentData data;

  final DateTime updatedAt;

  final String updatedBy;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ResidentView &&
    other.id == id &&
    other.revision == revision &&
    other.data == data &&
    other.updatedAt == updatedAt &&
    other.updatedBy == updatedBy;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (revision.hashCode) +
    (data.hashCode) +
    (updatedAt.hashCode) +
    (updatedBy.hashCode);

  @override
  String toString() => 'ResidentView[id=$id, revision=$revision, data=$data, updatedAt=$updatedAt, updatedBy=$updatedBy]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'revision'] = this.revision;
      json[r'data'] = this.data;
      json[r'updated_at'] = this.updatedAt.toUtc().toIso8601String();
      json[r'updated_by'] = this.updatedBy;
    return json;
  }

  /// Clones this instance of [ResidentView] and returns a new one where some of the
  /// properties have changed.
  ResidentView copyWith({
    String? id,
    int? revision,
    ResidentData? data,
    DateTime? updatedAt,
    String? updatedBy,
  }) => ResidentView(
    id: id ?? this.id,
    revision: revision ?? this.revision,
    data: data ?? this.data,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedBy: updatedBy ?? this.updatedBy,
  );

  /// Returns a new [ResidentView] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ResidentView? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'), 'Required key "ResidentView[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "ResidentView[id]" has a null value in JSON.');
        assert(json.containsKey(r'revision'), 'Required key "ResidentView[revision]" is missing from JSON.');
        assert(json[r'revision'] != null, 'Required key "ResidentView[revision]" has a null value in JSON.');
        assert(json.containsKey(r'data'), 'Required key "ResidentView[data]" is missing from JSON.');
        assert(json[r'data'] != null, 'Required key "ResidentView[data]" has a null value in JSON.');
        assert(json.containsKey(r'updated_at'), 'Required key "ResidentView[updated_at]" is missing from JSON.');
        assert(json[r'updated_at'] != null, 'Required key "ResidentView[updated_at]" has a null value in JSON.');
        assert(json.containsKey(r'updated_by'), 'Required key "ResidentView[updated_by]" is missing from JSON.');
        assert(json[r'updated_by'] != null, 'Required key "ResidentView[updated_by]" has a null value in JSON.');
        return true;
      }());

      return ResidentView(
        id: mapValueOfType<String>(json, r'id')!,
        revision: mapValueOfType<int>(json, r'revision')!,
        data: ResidentData.fromJson(json[r'data'])!,
        updatedAt: mapDateTime(json, r'updated_at', r'')!,
        updatedBy: mapValueOfType<String>(json, r'updated_by')!,
      );
    }
    return null;
  }

  static List<ResidentView> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ResidentView>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ResidentView.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ResidentView> mapFromJson(dynamic json) {
    final map = <String, ResidentView>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ResidentView.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ResidentView-objects as value to a dart map
  static Map<String, List<ResidentView>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ResidentView>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ResidentView.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'revision',
    'data',
    'updated_at',
    'updated_by',
  };
}


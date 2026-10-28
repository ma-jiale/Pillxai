//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ResidentData {
  /// Returns a new [ResidentData] instance.
  ResidentData({
    required this.name,
    this.bed = '',
    this.barcode,
    this.avatar,
  });

  final String name;

  final String bed;

  final String? barcode;

  final String? avatar;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ResidentData &&
    other.name == name &&
    other.bed == bed &&
    other.barcode == barcode &&
    other.avatar == avatar;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (name.hashCode) +
    (bed.hashCode) +
    (barcode == null ? 0 : barcode!.hashCode) +
    (avatar == null ? 0 : avatar!.hashCode);

  @override
  String toString() => 'ResidentData[name=$name, bed=$bed, barcode=$barcode, avatar=$avatar]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'name'] = this.name;
      json[r'bed'] = this.bed;
    if (this.barcode != null) {
      json[r'barcode'] = this.barcode;
    } else {
      json[r'barcode'] = null;
    }
    if (this.avatar != null) {
      json[r'avatar'] = this.avatar;
    } else {
      json[r'avatar'] = null;
    }
    return json;
  }

  /// Clones this instance of [ResidentData] and returns a new one where some of the
  /// properties have changed.
  ResidentData copyWith({
    String? name,
    String? bed,
    String? barcode,
    bool barcodeSetToNull = false,
    String? avatar,
    bool avatarSetToNull = false,
  }) => ResidentData(
    name: name ?? this.name,
    bed: bed ?? this.bed,
    barcode: barcodeSetToNull ? null : barcode ?? this.barcode,
    avatar: avatarSetToNull ? null : avatar ?? this.avatar,
  );

  /// Returns a new [ResidentData] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ResidentData? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'name'), 'Required key "ResidentData[name]" is missing from JSON.');
        assert(json[r'name'] != null, 'Required key "ResidentData[name]" has a null value in JSON.');
        return true;
      }());

      return ResidentData(
        name: mapValueOfType<String>(json, r'name')!,
        bed: mapValueOfType<String>(json, r'bed') ?? '',
        barcode: mapValueOfType<String>(json, r'barcode'),
        avatar: mapValueOfType<String>(json, r'avatar'),
      );
    }
    return null;
  }

  static List<ResidentData> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ResidentData>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ResidentData.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ResidentData> mapFromJson(dynamic json) {
    final map = <String, ResidentData>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ResidentData.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ResidentData-objects as value to a dart map
  static Map<String, List<ResidentData>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ResidentData>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ResidentData.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'name',
  };
}


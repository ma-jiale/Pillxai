//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class LabelView {
  /// Returns a new [LabelView] instance.
  LabelView({
    required this.uid,
    required this.residentId,
  });

  final String uid;

  final String residentId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is LabelView &&
    other.uid == uid &&
    other.residentId == residentId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (uid.hashCode) +
    (residentId.hashCode);

  @override
  String toString() => 'LabelView[uid=$uid, residentId=$residentId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'uid'] = this.uid;
      json[r'resident_id'] = this.residentId;
    return json;
  }

  /// Clones this instance of [LabelView] and returns a new one where some of the
  /// properties have changed.
  LabelView copyWith({
    String? uid,
    String? residentId,
  }) => LabelView(
    uid: uid ?? this.uid,
    residentId: residentId ?? this.residentId,
  );

  /// Returns a new [LabelView] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static LabelView? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'uid'), 'Required key "LabelView[uid]" is missing from JSON.');
        assert(json[r'uid'] != null, 'Required key "LabelView[uid]" has a null value in JSON.');
        assert(json.containsKey(r'resident_id'), 'Required key "LabelView[resident_id]" is missing from JSON.');
        assert(json[r'resident_id'] != null, 'Required key "LabelView[resident_id]" has a null value in JSON.');
        return true;
      }());

      return LabelView(
        uid: mapValueOfType<String>(json, r'uid')!,
        residentId: mapValueOfType<String>(json, r'resident_id')!,
      );
    }
    return null;
  }

  static List<LabelView> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <LabelView>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = LabelView.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, LabelView> mapFromJson(dynamic json) {
    final map = <String, LabelView>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = LabelView.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of LabelView-objects as value to a dart map
  static Map<String, List<LabelView>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<LabelView>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = LabelView.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'uid',
    'resident_id',
  };
}


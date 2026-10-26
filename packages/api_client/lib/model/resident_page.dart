//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ResidentPage {
  /// Returns a new [ResidentPage] instance.
  ResidentPage({
    this.items = const [],
    required this.nextAfter,
  });

  final List<ResidentView> items;

  final String? nextAfter;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ResidentPage &&
    _deepEquality.equals(other.items, items) &&
    other.nextAfter == nextAfter;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (items.hashCode) +
    (nextAfter == null ? 0 : nextAfter!.hashCode);

  @override
  String toString() => 'ResidentPage[items=$items, nextAfter=$nextAfter]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'items'] = this.items;
    if (this.nextAfter != null) {
      json[r'next_after'] = this.nextAfter;
    } else {
      json[r'next_after'] = null;
    }
    return json;
  }

  /// Clones this instance of [ResidentPage] and returns a new one where some of the
  /// properties have changed.
  ResidentPage copyWith({
    List<ResidentView>? items,
    String? nextAfter,
    bool nextAfterSetToNull = false,
  }) => ResidentPage(
    items: items ?? this.items,
    nextAfter: nextAfterSetToNull ? null : nextAfter ?? this.nextAfter,
  );

  /// Returns a new [ResidentPage] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ResidentPage? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'items'), 'Required key "ResidentPage[items]" is missing from JSON.');
        assert(json[r'items'] != null, 'Required key "ResidentPage[items]" has a null value in JSON.');
        assert(json.containsKey(r'next_after'), 'Required key "ResidentPage[next_after]" is missing from JSON.');
        return true;
      }());

      return ResidentPage(
        items: ResidentView.listFromJson(json[r'items']),
        nextAfter: mapValueOfType<String>(json, r'next_after'),
      );
    }
    return null;
  }

  static List<ResidentPage> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ResidentPage>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ResidentPage.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ResidentPage> mapFromJson(dynamic json) {
    final map = <String, ResidentPage>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ResidentPage.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ResidentPage-objects as value to a dart map
  static Map<String, List<ResidentPage>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ResidentPage>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ResidentPage.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'items',
    'next_after',
  };
}


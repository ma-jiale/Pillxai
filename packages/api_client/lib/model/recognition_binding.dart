//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class RecognitionBinding {
  /// Returns a new [RecognitionBinding] instance.
  RecognitionBinding({
    required this.source_,
    required this.value,
    required this.residentId,
  });

  final RecognitionBindingSource_Enum source_;

  final String value;

  final String residentId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is RecognitionBinding &&
    other.source_ == source_ &&
    other.value == value &&
    other.residentId == residentId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (source_.hashCode) +
    (value.hashCode) +
    (residentId.hashCode);

  @override
  String toString() => 'RecognitionBinding[source_=$source_, value=$value, residentId=$residentId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'source'] = this.source_;
      json[r'value'] = this.value;
      json[r'resident_id'] = this.residentId;
    return json;
  }

  /// Clones this instance of [RecognitionBinding] and returns a new one where some of the
  /// properties have changed.
  RecognitionBinding copyWith({
    RecognitionBindingSource_Enum? source_,
    String? value,
    String? residentId,
  }) => RecognitionBinding(
    source_: source_ ?? this.source_,
    value: value ?? this.value,
    residentId: residentId ?? this.residentId,
  );

  /// Returns a new [RecognitionBinding] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static RecognitionBinding? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'source'), 'Required key "RecognitionBinding[source]" is missing from JSON.');
        assert(json[r'source'] != null, 'Required key "RecognitionBinding[source]" has a null value in JSON.');
        assert(json.containsKey(r'value'), 'Required key "RecognitionBinding[value]" is missing from JSON.');
        assert(json[r'value'] != null, 'Required key "RecognitionBinding[value]" has a null value in JSON.');
        assert(json.containsKey(r'resident_id'), 'Required key "RecognitionBinding[resident_id]" is missing from JSON.');
        assert(json[r'resident_id'] != null, 'Required key "RecognitionBinding[resident_id]" has a null value in JSON.');
        return true;
      }());

      return RecognitionBinding(
        source_: RecognitionBindingSource_Enum.fromJson(json[r'source'])!,
        value: mapValueOfType<String>(json, r'value')!,
        residentId: mapValueOfType<String>(json, r'resident_id')!,
      );
    }
    return null;
  }

  static List<RecognitionBinding> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RecognitionBinding>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RecognitionBinding.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, RecognitionBinding> mapFromJson(dynamic json) {
    final map = <String, RecognitionBinding>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = RecognitionBinding.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of RecognitionBinding-objects as value to a dart map
  static Map<String, List<RecognitionBinding>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<RecognitionBinding>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = RecognitionBinding.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'source',
    'value',
    'resident_id',
  };
}


enum RecognitionBindingSource_Enum {
  rfid._(r'rfid'),
  barcode._(r'barcode'),
  ;

  /// Instantiate a new enum with the provided value.
  const RecognitionBindingSource_Enum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [RecognitionBindingSource_Enum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static RecognitionBindingSource_Enum? fromJson(dynamic value) => RecognitionBindingSource_EnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [RecognitionBindingSource_Enum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<RecognitionBindingSource_Enum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RecognitionBindingSource_Enum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RecognitionBindingSource_Enum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [RecognitionBindingSource_Enum] to String,
/// and [decode] dynamic data back to [RecognitionBindingSource_Enum].
class RecognitionBindingSource_EnumTypeTransformer {
  factory RecognitionBindingSource_EnumTypeTransformer() => _instance ??= const RecognitionBindingSource_EnumTypeTransformer._();

  const RecognitionBindingSource_EnumTypeTransformer._();

  String encode(RecognitionBindingSource_Enum data) => data._value;

  /// Returns the instance of [RecognitionBindingSource_Enum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  RecognitionBindingSource_Enum? decode(dynamic data, {bool allowNull = true}) {
    if (data is RecognitionBindingSource_Enum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'rfid': return RecognitionBindingSource_Enum.rfid;
        case r'barcode': return RecognitionBindingSource_Enum.barcode;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static RecognitionBindingSource_EnumTypeTransformer? _instance;
}



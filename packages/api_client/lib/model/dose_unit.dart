//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


enum DoseUnit {
  tablet._(r'tablet'),
  capsule._(r'capsule'),
  ;

  /// Instantiate a new enum with the provided value.
  const DoseUnit._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [DoseUnit] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static DoseUnit? fromJson(dynamic value) => DoseUnitTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [DoseUnit]
  /// that were successfully decoded from the passed [JSON][json].
  static List<DoseUnit> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <DoseUnit>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DoseUnit.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [DoseUnit] to String,
/// and [decode] dynamic data back to [DoseUnit].
class DoseUnitTypeTransformer {
  factory DoseUnitTypeTransformer() => _instance ??= const DoseUnitTypeTransformer._();

  const DoseUnitTypeTransformer._();

  /// Encodes this enum as a value suitable for JSON.
  String encode(DoseUnit data) => data._value;

  /// Returns the instance of [DoseUnit] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  DoseUnit? decode(dynamic data, {bool allowNull = true}) {
    if (data is DoseUnit) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'tablet': return DoseUnit.tablet;
        case r'capsule': return DoseUnit.capsule;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static DoseUnitTypeTransformer? _instance;
}


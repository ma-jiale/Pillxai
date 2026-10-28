//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;


enum FeedForm {
  whole._(r'whole'),
  half._(r'half'),
  ;

  /// Instantiate a new enum with the provided value.
  const FeedForm._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [FeedForm] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static FeedForm? fromJson(dynamic value) => FeedFormTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [FeedForm]
  /// that were successfully decoded from the passed [JSON][json].
  static List<FeedForm> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <FeedForm>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = FeedForm.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [FeedForm] to String,
/// and [decode] dynamic data back to [FeedForm].
class FeedFormTypeTransformer {
  factory FeedFormTypeTransformer() => _instance ??= const FeedFormTypeTransformer._();

  const FeedFormTypeTransformer._();

  /// Encodes this enum as a value suitable for JSON.
  String encode(FeedForm data) => data._value;

  /// Returns the instance of [FeedForm] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  FeedForm? decode(dynamic data, {bool allowNull = true}) {
    if (data is FeedForm) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'whole': return FeedForm.whole;
        case r'half': return FeedForm.half;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static FeedFormTypeTransformer? _instance;
}


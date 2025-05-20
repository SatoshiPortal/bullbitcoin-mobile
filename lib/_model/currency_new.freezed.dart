// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'currency_new.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

CurrencyNew _$CurrencyNewFromJson(Map<String, dynamic> json) {
  return _CurrencyNew.fromJson(json);
}

/// @nodoc
mixin _$CurrencyNew {
  String get name => throw _privateConstructorUsedError;
  double get price => throw _privateConstructorUsedError;
  String get code => throw _privateConstructorUsedError;
  bool get isFiat => throw _privateConstructorUsedError;
  String? get logoPath => throw _privateConstructorUsedError;

  /// Serializes this CurrencyNew to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CurrencyNew
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CurrencyNewCopyWith<CurrencyNew> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CurrencyNewCopyWith<$Res> {
  factory $CurrencyNewCopyWith(
          CurrencyNew value, $Res Function(CurrencyNew) then) =
      _$CurrencyNewCopyWithImpl<$Res, CurrencyNew>;
  @useResult
  $Res call(
      {String name, double price, String code, bool isFiat, String? logoPath});
}

/// @nodoc
class _$CurrencyNewCopyWithImpl<$Res, $Val extends CurrencyNew>
    implements $CurrencyNewCopyWith<$Res> {
  _$CurrencyNewCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CurrencyNew
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? price = null,
    Object? code = null,
    Object? isFiat = null,
    Object? logoPath = freezed,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      isFiat: null == isFiat
          ? _value.isFiat
          : isFiat // ignore: cast_nullable_to_non_nullable
              as bool,
      logoPath: freezed == logoPath
          ? _value.logoPath
          : logoPath // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CurrencyNewImplCopyWith<$Res>
    implements $CurrencyNewCopyWith<$Res> {
  factory _$$CurrencyNewImplCopyWith(
          _$CurrencyNewImpl value, $Res Function(_$CurrencyNewImpl) then) =
      __$$CurrencyNewImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name, double price, String code, bool isFiat, String? logoPath});
}

/// @nodoc
class __$$CurrencyNewImplCopyWithImpl<$Res>
    extends _$CurrencyNewCopyWithImpl<$Res, _$CurrencyNewImpl>
    implements _$$CurrencyNewImplCopyWith<$Res> {
  __$$CurrencyNewImplCopyWithImpl(
      _$CurrencyNewImpl _value, $Res Function(_$CurrencyNewImpl) _then)
      : super(_value, _then);

  /// Create a copy of CurrencyNew
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? price = null,
    Object? code = null,
    Object? isFiat = null,
    Object? logoPath = freezed,
  }) {
    return _then(_$CurrencyNewImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      isFiat: null == isFiat
          ? _value.isFiat
          : isFiat // ignore: cast_nullable_to_non_nullable
              as bool,
      logoPath: freezed == logoPath
          ? _value.logoPath
          : logoPath // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CurrencyNewImpl extends _CurrencyNew {
  const _$CurrencyNewImpl(
      {required this.name,
      required this.price,
      required this.code,
      required this.isFiat,
      this.logoPath = ''})
      : super._();

  factory _$CurrencyNewImpl.fromJson(Map<String, dynamic> json) =>
      _$$CurrencyNewImplFromJson(json);

  @override
  final String name;
  @override
  final double price;
  @override
  final String code;
  @override
  final bool isFiat;
  @override
  @JsonKey()
  final String? logoPath;

  @override
  String toString() {
    return 'CurrencyNew(name: $name, price: $price, code: $code, isFiat: $isFiat, logoPath: $logoPath)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CurrencyNewImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.isFiat, isFiat) || other.isFiat == isFiat) &&
            (identical(other.logoPath, logoPath) ||
                other.logoPath == logoPath));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, name, price, code, isFiat, logoPath);

  /// Create a copy of CurrencyNew
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CurrencyNewImplCopyWith<_$CurrencyNewImpl> get copyWith =>
      __$$CurrencyNewImplCopyWithImpl<_$CurrencyNewImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CurrencyNewImplToJson(
      this,
    );
  }
}

abstract class _CurrencyNew extends CurrencyNew {
  const factory _CurrencyNew(
      {required final String name,
      required final double price,
      required final String code,
      required final bool isFiat,
      final String? logoPath}) = _$CurrencyNewImpl;
  const _CurrencyNew._() : super._();

  factory _CurrencyNew.fromJson(Map<String, dynamic> json) =
      _$CurrencyNewImpl.fromJson;

  @override
  String get name;
  @override
  double get price;
  @override
  String get code;
  @override
  bool get isFiat;
  @override
  String? get logoPath;

  /// Create a copy of CurrencyNew
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CurrencyNewImplCopyWith<_$CurrencyNewImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

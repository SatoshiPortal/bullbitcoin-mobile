// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

CurrencyState _$CurrencyStateFromJson(Map<String, dynamic> json) {
  return _CurrencyState.fromJson(json);
}

/// @nodoc
mixin _$CurrencyState {
  bool get unitsInSats => throw _privateConstructorUsedError;
  bool get fiatSelected => throw _privateConstructorUsedError;
  Currency? get currency => throw _privateConstructorUsedError;
  Currency? get defaultFiatCurrency => throw _privateConstructorUsedError;
  List<Currency>? get currencyList => throw _privateConstructorUsedError;
  DateTime? get lastUpdatedCurrency => throw _privateConstructorUsedError;
  bool get loadingCurrency => throw _privateConstructorUsedError;
  String get errLoadingCurrency => throw _privateConstructorUsedError;
  double get fiatAmt => throw _privateConstructorUsedError;
  int get amount => throw _privateConstructorUsedError;
  String? get tempAmount => throw _privateConstructorUsedError;
  String get errAmount => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $CurrencyStateCopyWith<CurrencyState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CurrencyStateCopyWith<$Res> {
  factory $CurrencyStateCopyWith(
          CurrencyState value, $Res Function(CurrencyState) then) =
      _$CurrencyStateCopyWithImpl<$Res, CurrencyState>;
  @useResult
  $Res call(
      {bool unitsInSats,
      bool fiatSelected,
      Currency? currency,
      Currency? defaultFiatCurrency,
      List<Currency>? currencyList,
      DateTime? lastUpdatedCurrency,
      bool loadingCurrency,
      String errLoadingCurrency,
      double fiatAmt,
      int amount,
      String? tempAmount,
      String errAmount});

  $CurrencyCopyWith<$Res>? get currency;
  $CurrencyCopyWith<$Res>? get defaultFiatCurrency;
}

/// @nodoc
class _$CurrencyStateCopyWithImpl<$Res, $Val extends CurrencyState>
    implements $CurrencyStateCopyWith<$Res> {
  _$CurrencyStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? unitsInSats = null,
    Object? fiatSelected = null,
    Object? currency = freezed,
    Object? defaultFiatCurrency = freezed,
    Object? currencyList = freezed,
    Object? lastUpdatedCurrency = freezed,
    Object? loadingCurrency = null,
    Object? errLoadingCurrency = null,
    Object? fiatAmt = null,
    Object? amount = null,
    Object? tempAmount = freezed,
    Object? errAmount = null,
  }) {
    return _then(_value.copyWith(
      unitsInSats: null == unitsInSats
          ? _value.unitsInSats
          : unitsInSats // ignore: cast_nullable_to_non_nullable
              as bool,
      fiatSelected: null == fiatSelected
          ? _value.fiatSelected
          : fiatSelected // ignore: cast_nullable_to_non_nullable
              as bool,
      currency: freezed == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as Currency?,
      defaultFiatCurrency: freezed == defaultFiatCurrency
          ? _value.defaultFiatCurrency
          : defaultFiatCurrency // ignore: cast_nullable_to_non_nullable
              as Currency?,
      currencyList: freezed == currencyList
          ? _value.currencyList
          : currencyList // ignore: cast_nullable_to_non_nullable
              as List<Currency>?,
      lastUpdatedCurrency: freezed == lastUpdatedCurrency
          ? _value.lastUpdatedCurrency
          : lastUpdatedCurrency // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      loadingCurrency: null == loadingCurrency
          ? _value.loadingCurrency
          : loadingCurrency // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingCurrency: null == errLoadingCurrency
          ? _value.errLoadingCurrency
          : errLoadingCurrency // ignore: cast_nullable_to_non_nullable
              as String,
      fiatAmt: null == fiatAmt
          ? _value.fiatAmt
          : fiatAmt // ignore: cast_nullable_to_non_nullable
              as double,
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as int,
      tempAmount: freezed == tempAmount
          ? _value.tempAmount
          : tempAmount // ignore: cast_nullable_to_non_nullable
              as String?,
      errAmount: null == errAmount
          ? _value.errAmount
          : errAmount // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $CurrencyCopyWith<$Res>? get currency {
    if (_value.currency == null) {
      return null;
    }

    return $CurrencyCopyWith<$Res>(_value.currency!, (value) {
      return _then(_value.copyWith(currency: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $CurrencyCopyWith<$Res>? get defaultFiatCurrency {
    if (_value.defaultFiatCurrency == null) {
      return null;
    }

    return $CurrencyCopyWith<$Res>(_value.defaultFiatCurrency!, (value) {
      return _then(_value.copyWith(defaultFiatCurrency: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$CurrencyStateImplCopyWith<$Res>
    implements $CurrencyStateCopyWith<$Res> {
  factory _$$CurrencyStateImplCopyWith(
          _$CurrencyStateImpl value, $Res Function(_$CurrencyStateImpl) then) =
      __$$CurrencyStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool unitsInSats,
      bool fiatSelected,
      Currency? currency,
      Currency? defaultFiatCurrency,
      List<Currency>? currencyList,
      DateTime? lastUpdatedCurrency,
      bool loadingCurrency,
      String errLoadingCurrency,
      double fiatAmt,
      int amount,
      String? tempAmount,
      String errAmount});

  @override
  $CurrencyCopyWith<$Res>? get currency;
  @override
  $CurrencyCopyWith<$Res>? get defaultFiatCurrency;
}

/// @nodoc
class __$$CurrencyStateImplCopyWithImpl<$Res>
    extends _$CurrencyStateCopyWithImpl<$Res, _$CurrencyStateImpl>
    implements _$$CurrencyStateImplCopyWith<$Res> {
  __$$CurrencyStateImplCopyWithImpl(
      _$CurrencyStateImpl _value, $Res Function(_$CurrencyStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? unitsInSats = null,
    Object? fiatSelected = null,
    Object? currency = freezed,
    Object? defaultFiatCurrency = freezed,
    Object? currencyList = freezed,
    Object? lastUpdatedCurrency = freezed,
    Object? loadingCurrency = null,
    Object? errLoadingCurrency = null,
    Object? fiatAmt = null,
    Object? amount = null,
    Object? tempAmount = freezed,
    Object? errAmount = null,
  }) {
    return _then(_$CurrencyStateImpl(
      unitsInSats: null == unitsInSats
          ? _value.unitsInSats
          : unitsInSats // ignore: cast_nullable_to_non_nullable
              as bool,
      fiatSelected: null == fiatSelected
          ? _value.fiatSelected
          : fiatSelected // ignore: cast_nullable_to_non_nullable
              as bool,
      currency: freezed == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as Currency?,
      defaultFiatCurrency: freezed == defaultFiatCurrency
          ? _value.defaultFiatCurrency
          : defaultFiatCurrency // ignore: cast_nullable_to_non_nullable
              as Currency?,
      currencyList: freezed == currencyList
          ? _value._currencyList
          : currencyList // ignore: cast_nullable_to_non_nullable
              as List<Currency>?,
      lastUpdatedCurrency: freezed == lastUpdatedCurrency
          ? _value.lastUpdatedCurrency
          : lastUpdatedCurrency // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      loadingCurrency: null == loadingCurrency
          ? _value.loadingCurrency
          : loadingCurrency // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingCurrency: null == errLoadingCurrency
          ? _value.errLoadingCurrency
          : errLoadingCurrency // ignore: cast_nullable_to_non_nullable
              as String,
      fiatAmt: null == fiatAmt
          ? _value.fiatAmt
          : fiatAmt // ignore: cast_nullable_to_non_nullable
              as double,
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as int,
      tempAmount: freezed == tempAmount
          ? _value.tempAmount
          : tempAmount // ignore: cast_nullable_to_non_nullable
              as String?,
      errAmount: null == errAmount
          ? _value.errAmount
          : errAmount // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CurrencyStateImpl extends _CurrencyState {
  const _$CurrencyStateImpl(
      {this.unitsInSats = false,
      this.fiatSelected = false,
      this.currency,
      this.defaultFiatCurrency,
      final List<Currency>? currencyList,
      this.lastUpdatedCurrency,
      this.loadingCurrency = false,
      this.errLoadingCurrency = '',
      this.fiatAmt = 0,
      this.amount = 0,
      this.tempAmount,
      this.errAmount = ''})
      : _currencyList = currencyList,
        super._();

  factory _$CurrencyStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$CurrencyStateImplFromJson(json);

  @override
  @JsonKey()
  final bool unitsInSats;
  @override
  @JsonKey()
  final bool fiatSelected;
  @override
  final Currency? currency;
  @override
  final Currency? defaultFiatCurrency;
  final List<Currency>? _currencyList;
  @override
  List<Currency>? get currencyList {
    final value = _currencyList;
    if (value == null) return null;
    if (_currencyList is EqualUnmodifiableListView) return _currencyList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final DateTime? lastUpdatedCurrency;
  @override
  @JsonKey()
  final bool loadingCurrency;
  @override
  @JsonKey()
  final String errLoadingCurrency;
  @override
  @JsonKey()
  final double fiatAmt;
  @override
  @JsonKey()
  final int amount;
  @override
  final String? tempAmount;
  @override
  @JsonKey()
  final String errAmount;

  @override
  String toString() {
    return 'CurrencyState(unitsInSats: $unitsInSats, fiatSelected: $fiatSelected, currency: $currency, defaultFiatCurrency: $defaultFiatCurrency, currencyList: $currencyList, lastUpdatedCurrency: $lastUpdatedCurrency, loadingCurrency: $loadingCurrency, errLoadingCurrency: $errLoadingCurrency, fiatAmt: $fiatAmt, amount: $amount, tempAmount: $tempAmount, errAmount: $errAmount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CurrencyStateImpl &&
            (identical(other.unitsInSats, unitsInSats) ||
                other.unitsInSats == unitsInSats) &&
            (identical(other.fiatSelected, fiatSelected) ||
                other.fiatSelected == fiatSelected) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.defaultFiatCurrency, defaultFiatCurrency) ||
                other.defaultFiatCurrency == defaultFiatCurrency) &&
            const DeepCollectionEquality()
                .equals(other._currencyList, _currencyList) &&
            (identical(other.lastUpdatedCurrency, lastUpdatedCurrency) ||
                other.lastUpdatedCurrency == lastUpdatedCurrency) &&
            (identical(other.loadingCurrency, loadingCurrency) ||
                other.loadingCurrency == loadingCurrency) &&
            (identical(other.errLoadingCurrency, errLoadingCurrency) ||
                other.errLoadingCurrency == errLoadingCurrency) &&
            (identical(other.fiatAmt, fiatAmt) || other.fiatAmt == fiatAmt) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.tempAmount, tempAmount) ||
                other.tempAmount == tempAmount) &&
            (identical(other.errAmount, errAmount) ||
                other.errAmount == errAmount));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      unitsInSats,
      fiatSelected,
      currency,
      defaultFiatCurrency,
      const DeepCollectionEquality().hash(_currencyList),
      lastUpdatedCurrency,
      loadingCurrency,
      errLoadingCurrency,
      fiatAmt,
      amount,
      tempAmount,
      errAmount);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CurrencyStateImplCopyWith<_$CurrencyStateImpl> get copyWith =>
      __$$CurrencyStateImplCopyWithImpl<_$CurrencyStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CurrencyStateImplToJson(
      this,
    );
  }
}

abstract class _CurrencyState extends CurrencyState {
  const factory _CurrencyState(
      {final bool unitsInSats,
      final bool fiatSelected,
      final Currency? currency,
      final Currency? defaultFiatCurrency,
      final List<Currency>? currencyList,
      final DateTime? lastUpdatedCurrency,
      final bool loadingCurrency,
      final String errLoadingCurrency,
      final double fiatAmt,
      final int amount,
      final String? tempAmount,
      final String errAmount}) = _$CurrencyStateImpl;
  const _CurrencyState._() : super._();

  factory _CurrencyState.fromJson(Map<String, dynamic> json) =
      _$CurrencyStateImpl.fromJson;

  @override
  bool get unitsInSats;
  @override
  bool get fiatSelected;
  @override
  Currency? get currency;
  @override
  Currency? get defaultFiatCurrency;
  @override
  List<Currency>? get currencyList;
  @override
  DateTime? get lastUpdatedCurrency;
  @override
  bool get loadingCurrency;
  @override
  String get errLoadingCurrency;
  @override
  double get fiatAmt;
  @override
  int get amount;
  @override
  String? get tempAmount;
  @override
  String get errAmount;
  @override
  @JsonKey(ignore: true)
  _$$CurrencyStateImplCopyWith<_$CurrencyStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

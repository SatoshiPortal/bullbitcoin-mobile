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
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$ReceiveState {
  bool get loadingAddress => throw _privateConstructorUsedError;
  String get errLoadingAddress => throw _privateConstructorUsedError;
  Address? get defaultAddress => throw _privateConstructorUsedError;
  String get privateLabel => throw _privateConstructorUsedError;
  bool get savingLabel => throw _privateConstructorUsedError;
  String get errSavingLabel => throw _privateConstructorUsedError;
  bool get labelSaved => throw _privateConstructorUsedError;
  int get invoiceAmount => throw _privateConstructorUsedError;
  int get savedInvoiceAmount => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get savedDescription => throw _privateConstructorUsedError;
  bool get creatingInvoice => throw _privateConstructorUsedError;
  String get errCreatingInvoice =>
      throw _privateConstructorUsedError; // Address? newInvoiceAddress,
  Currency? get selectedCurrency => throw _privateConstructorUsedError;
  List<Currency>? get currencyList => throw _privateConstructorUsedError;
  bool get isSats => throw _privateConstructorUsedError;
  bool get fiatSelected => throw _privateConstructorUsedError;
  double get fiatAmt => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ReceiveStateCopyWith<ReceiveState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReceiveStateCopyWith<$Res> {
  factory $ReceiveStateCopyWith(
          ReceiveState value, $Res Function(ReceiveState) then) =
      _$ReceiveStateCopyWithImpl<$Res, ReceiveState>;
  @useResult
  $Res call(
      {bool loadingAddress,
      String errLoadingAddress,
      Address? defaultAddress,
      String privateLabel,
      bool savingLabel,
      String errSavingLabel,
      bool labelSaved,
      int invoiceAmount,
      int savedInvoiceAmount,
      String description,
      String savedDescription,
      bool creatingInvoice,
      String errCreatingInvoice,
      Currency? selectedCurrency,
      List<Currency>? currencyList,
      bool isSats,
      bool fiatSelected,
      double fiatAmt});

  $AddressCopyWith<$Res>? get defaultAddress;
  $CurrencyCopyWith<$Res>? get selectedCurrency;
}

/// @nodoc
class _$ReceiveStateCopyWithImpl<$Res, $Val extends ReceiveState>
    implements $ReceiveStateCopyWith<$Res> {
  _$ReceiveStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? loadingAddress = null,
    Object? errLoadingAddress = null,
    Object? defaultAddress = freezed,
    Object? privateLabel = null,
    Object? savingLabel = null,
    Object? errSavingLabel = null,
    Object? labelSaved = null,
    Object? invoiceAmount = null,
    Object? savedInvoiceAmount = null,
    Object? description = null,
    Object? savedDescription = null,
    Object? creatingInvoice = null,
    Object? errCreatingInvoice = null,
    Object? selectedCurrency = freezed,
    Object? currencyList = freezed,
    Object? isSats = null,
    Object? fiatSelected = null,
    Object? fiatAmt = null,
  }) {
    return _then(_value.copyWith(
      loadingAddress: null == loadingAddress
          ? _value.loadingAddress
          : loadingAddress // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingAddress: null == errLoadingAddress
          ? _value.errLoadingAddress
          : errLoadingAddress // ignore: cast_nullable_to_non_nullable
              as String,
      defaultAddress: freezed == defaultAddress
          ? _value.defaultAddress
          : defaultAddress // ignore: cast_nullable_to_non_nullable
              as Address?,
      privateLabel: null == privateLabel
          ? _value.privateLabel
          : privateLabel // ignore: cast_nullable_to_non_nullable
              as String,
      savingLabel: null == savingLabel
          ? _value.savingLabel
          : savingLabel // ignore: cast_nullable_to_non_nullable
              as bool,
      errSavingLabel: null == errSavingLabel
          ? _value.errSavingLabel
          : errSavingLabel // ignore: cast_nullable_to_non_nullable
              as String,
      labelSaved: null == labelSaved
          ? _value.labelSaved
          : labelSaved // ignore: cast_nullable_to_non_nullable
              as bool,
      invoiceAmount: null == invoiceAmount
          ? _value.invoiceAmount
          : invoiceAmount // ignore: cast_nullable_to_non_nullable
              as int,
      savedInvoiceAmount: null == savedInvoiceAmount
          ? _value.savedInvoiceAmount
          : savedInvoiceAmount // ignore: cast_nullable_to_non_nullable
              as int,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      savedDescription: null == savedDescription
          ? _value.savedDescription
          : savedDescription // ignore: cast_nullable_to_non_nullable
              as String,
      creatingInvoice: null == creatingInvoice
          ? _value.creatingInvoice
          : creatingInvoice // ignore: cast_nullable_to_non_nullable
              as bool,
      errCreatingInvoice: null == errCreatingInvoice
          ? _value.errCreatingInvoice
          : errCreatingInvoice // ignore: cast_nullable_to_non_nullable
              as String,
      selectedCurrency: freezed == selectedCurrency
          ? _value.selectedCurrency
          : selectedCurrency // ignore: cast_nullable_to_non_nullable
              as Currency?,
      currencyList: freezed == currencyList
          ? _value.currencyList
          : currencyList // ignore: cast_nullable_to_non_nullable
              as List<Currency>?,
      isSats: null == isSats
          ? _value.isSats
          : isSats // ignore: cast_nullable_to_non_nullable
              as bool,
      fiatSelected: null == fiatSelected
          ? _value.fiatSelected
          : fiatSelected // ignore: cast_nullable_to_non_nullable
              as bool,
      fiatAmt: null == fiatAmt
          ? _value.fiatAmt
          : fiatAmt // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $AddressCopyWith<$Res>? get defaultAddress {
    if (_value.defaultAddress == null) {
      return null;
    }

    return $AddressCopyWith<$Res>(_value.defaultAddress!, (value) {
      return _then(_value.copyWith(defaultAddress: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $CurrencyCopyWith<$Res>? get selectedCurrency {
    if (_value.selectedCurrency == null) {
      return null;
    }

    return $CurrencyCopyWith<$Res>(_value.selectedCurrency!, (value) {
      return _then(_value.copyWith(selectedCurrency: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ReceiveStateImplCopyWith<$Res>
    implements $ReceiveStateCopyWith<$Res> {
  factory _$$ReceiveStateImplCopyWith(
          _$ReceiveStateImpl value, $Res Function(_$ReceiveStateImpl) then) =
      __$$ReceiveStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool loadingAddress,
      String errLoadingAddress,
      Address? defaultAddress,
      String privateLabel,
      bool savingLabel,
      String errSavingLabel,
      bool labelSaved,
      int invoiceAmount,
      int savedInvoiceAmount,
      String description,
      String savedDescription,
      bool creatingInvoice,
      String errCreatingInvoice,
      Currency? selectedCurrency,
      List<Currency>? currencyList,
      bool isSats,
      bool fiatSelected,
      double fiatAmt});

  @override
  $AddressCopyWith<$Res>? get defaultAddress;
  @override
  $CurrencyCopyWith<$Res>? get selectedCurrency;
}

/// @nodoc
class __$$ReceiveStateImplCopyWithImpl<$Res>
    extends _$ReceiveStateCopyWithImpl<$Res, _$ReceiveStateImpl>
    implements _$$ReceiveStateImplCopyWith<$Res> {
  __$$ReceiveStateImplCopyWithImpl(
      _$ReceiveStateImpl _value, $Res Function(_$ReceiveStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? loadingAddress = null,
    Object? errLoadingAddress = null,
    Object? defaultAddress = freezed,
    Object? privateLabel = null,
    Object? savingLabel = null,
    Object? errSavingLabel = null,
    Object? labelSaved = null,
    Object? invoiceAmount = null,
    Object? savedInvoiceAmount = null,
    Object? description = null,
    Object? savedDescription = null,
    Object? creatingInvoice = null,
    Object? errCreatingInvoice = null,
    Object? selectedCurrency = freezed,
    Object? currencyList = freezed,
    Object? isSats = null,
    Object? fiatSelected = null,
    Object? fiatAmt = null,
  }) {
    return _then(_$ReceiveStateImpl(
      loadingAddress: null == loadingAddress
          ? _value.loadingAddress
          : loadingAddress // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingAddress: null == errLoadingAddress
          ? _value.errLoadingAddress
          : errLoadingAddress // ignore: cast_nullable_to_non_nullable
              as String,
      defaultAddress: freezed == defaultAddress
          ? _value.defaultAddress
          : defaultAddress // ignore: cast_nullable_to_non_nullable
              as Address?,
      privateLabel: null == privateLabel
          ? _value.privateLabel
          : privateLabel // ignore: cast_nullable_to_non_nullable
              as String,
      savingLabel: null == savingLabel
          ? _value.savingLabel
          : savingLabel // ignore: cast_nullable_to_non_nullable
              as bool,
      errSavingLabel: null == errSavingLabel
          ? _value.errSavingLabel
          : errSavingLabel // ignore: cast_nullable_to_non_nullable
              as String,
      labelSaved: null == labelSaved
          ? _value.labelSaved
          : labelSaved // ignore: cast_nullable_to_non_nullable
              as bool,
      invoiceAmount: null == invoiceAmount
          ? _value.invoiceAmount
          : invoiceAmount // ignore: cast_nullable_to_non_nullable
              as int,
      savedInvoiceAmount: null == savedInvoiceAmount
          ? _value.savedInvoiceAmount
          : savedInvoiceAmount // ignore: cast_nullable_to_non_nullable
              as int,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      savedDescription: null == savedDescription
          ? _value.savedDescription
          : savedDescription // ignore: cast_nullable_to_non_nullable
              as String,
      creatingInvoice: null == creatingInvoice
          ? _value.creatingInvoice
          : creatingInvoice // ignore: cast_nullable_to_non_nullable
              as bool,
      errCreatingInvoice: null == errCreatingInvoice
          ? _value.errCreatingInvoice
          : errCreatingInvoice // ignore: cast_nullable_to_non_nullable
              as String,
      selectedCurrency: freezed == selectedCurrency
          ? _value.selectedCurrency
          : selectedCurrency // ignore: cast_nullable_to_non_nullable
              as Currency?,
      currencyList: freezed == currencyList
          ? _value._currencyList
          : currencyList // ignore: cast_nullable_to_non_nullable
              as List<Currency>?,
      isSats: null == isSats
          ? _value.isSats
          : isSats // ignore: cast_nullable_to_non_nullable
              as bool,
      fiatSelected: null == fiatSelected
          ? _value.fiatSelected
          : fiatSelected // ignore: cast_nullable_to_non_nullable
              as bool,
      fiatAmt: null == fiatAmt
          ? _value.fiatAmt
          : fiatAmt // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc

class _$ReceiveStateImpl extends _ReceiveState {
  const _$ReceiveStateImpl(
      {this.loadingAddress = true,
      this.errLoadingAddress = '',
      this.defaultAddress,
      this.privateLabel = '',
      this.savingLabel = false,
      this.errSavingLabel = '',
      this.labelSaved = false,
      this.invoiceAmount = 0,
      this.savedInvoiceAmount = 0,
      this.description = '',
      this.savedDescription = '',
      this.creatingInvoice = true,
      this.errCreatingInvoice = '',
      this.selectedCurrency,
      final List<Currency>? currencyList,
      this.isSats = false,
      this.fiatSelected = false,
      this.fiatAmt = 0})
      : _currencyList = currencyList,
        super._();

  @override
  @JsonKey()
  final bool loadingAddress;
  @override
  @JsonKey()
  final String errLoadingAddress;
  @override
  final Address? defaultAddress;
  @override
  @JsonKey()
  final String privateLabel;
  @override
  @JsonKey()
  final bool savingLabel;
  @override
  @JsonKey()
  final String errSavingLabel;
  @override
  @JsonKey()
  final bool labelSaved;
  @override
  @JsonKey()
  final int invoiceAmount;
  @override
  @JsonKey()
  final int savedInvoiceAmount;
  @override
  @JsonKey()
  final String description;
  @override
  @JsonKey()
  final String savedDescription;
  @override
  @JsonKey()
  final bool creatingInvoice;
  @override
  @JsonKey()
  final String errCreatingInvoice;
// Address? newInvoiceAddress,
  @override
  final Currency? selectedCurrency;
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
  @JsonKey()
  final bool isSats;
  @override
  @JsonKey()
  final bool fiatSelected;
  @override
  @JsonKey()
  final double fiatAmt;

  @override
  String toString() {
    return 'ReceiveState(loadingAddress: $loadingAddress, errLoadingAddress: $errLoadingAddress, defaultAddress: $defaultAddress, privateLabel: $privateLabel, savingLabel: $savingLabel, errSavingLabel: $errSavingLabel, labelSaved: $labelSaved, invoiceAmount: $invoiceAmount, savedInvoiceAmount: $savedInvoiceAmount, description: $description, savedDescription: $savedDescription, creatingInvoice: $creatingInvoice, errCreatingInvoice: $errCreatingInvoice, selectedCurrency: $selectedCurrency, currencyList: $currencyList, isSats: $isSats, fiatSelected: $fiatSelected, fiatAmt: $fiatAmt)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReceiveStateImpl &&
            (identical(other.loadingAddress, loadingAddress) ||
                other.loadingAddress == loadingAddress) &&
            (identical(other.errLoadingAddress, errLoadingAddress) ||
                other.errLoadingAddress == errLoadingAddress) &&
            (identical(other.defaultAddress, defaultAddress) ||
                other.defaultAddress == defaultAddress) &&
            (identical(other.privateLabel, privateLabel) ||
                other.privateLabel == privateLabel) &&
            (identical(other.savingLabel, savingLabel) ||
                other.savingLabel == savingLabel) &&
            (identical(other.errSavingLabel, errSavingLabel) ||
                other.errSavingLabel == errSavingLabel) &&
            (identical(other.labelSaved, labelSaved) ||
                other.labelSaved == labelSaved) &&
            (identical(other.invoiceAmount, invoiceAmount) ||
                other.invoiceAmount == invoiceAmount) &&
            (identical(other.savedInvoiceAmount, savedInvoiceAmount) ||
                other.savedInvoiceAmount == savedInvoiceAmount) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.savedDescription, savedDescription) ||
                other.savedDescription == savedDescription) &&
            (identical(other.creatingInvoice, creatingInvoice) ||
                other.creatingInvoice == creatingInvoice) &&
            (identical(other.errCreatingInvoice, errCreatingInvoice) ||
                other.errCreatingInvoice == errCreatingInvoice) &&
            (identical(other.selectedCurrency, selectedCurrency) ||
                other.selectedCurrency == selectedCurrency) &&
            const DeepCollectionEquality()
                .equals(other._currencyList, _currencyList) &&
            (identical(other.isSats, isSats) || other.isSats == isSats) &&
            (identical(other.fiatSelected, fiatSelected) ||
                other.fiatSelected == fiatSelected) &&
            (identical(other.fiatAmt, fiatAmt) || other.fiatAmt == fiatAmt));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      loadingAddress,
      errLoadingAddress,
      defaultAddress,
      privateLabel,
      savingLabel,
      errSavingLabel,
      labelSaved,
      invoiceAmount,
      savedInvoiceAmount,
      description,
      savedDescription,
      creatingInvoice,
      errCreatingInvoice,
      selectedCurrency,
      const DeepCollectionEquality().hash(_currencyList),
      isSats,
      fiatSelected,
      fiatAmt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ReceiveStateImplCopyWith<_$ReceiveStateImpl> get copyWith =>
      __$$ReceiveStateImplCopyWithImpl<_$ReceiveStateImpl>(this, _$identity);
}

abstract class _ReceiveState extends ReceiveState {
  const factory _ReceiveState(
      {final bool loadingAddress,
      final String errLoadingAddress,
      final Address? defaultAddress,
      final String privateLabel,
      final bool savingLabel,
      final String errSavingLabel,
      final bool labelSaved,
      final int invoiceAmount,
      final int savedInvoiceAmount,
      final String description,
      final String savedDescription,
      final bool creatingInvoice,
      final String errCreatingInvoice,
      final Currency? selectedCurrency,
      final List<Currency>? currencyList,
      final bool isSats,
      final bool fiatSelected,
      final double fiatAmt}) = _$ReceiveStateImpl;
  const _ReceiveState._() : super._();

  @override
  bool get loadingAddress;
  @override
  String get errLoadingAddress;
  @override
  Address? get defaultAddress;
  @override
  String get privateLabel;
  @override
  bool get savingLabel;
  @override
  String get errSavingLabel;
  @override
  bool get labelSaved;
  @override
  int get invoiceAmount;
  @override
  int get savedInvoiceAmount;
  @override
  String get description;
  @override
  String get savedDescription;
  @override
  bool get creatingInvoice;
  @override
  String get errCreatingInvoice;
  @override // Address? newInvoiceAddress,
  Currency? get selectedCurrency;
  @override
  List<Currency>? get currencyList;
  @override
  bool get isSats;
  @override
  bool get fiatSelected;
  @override
  double get fiatAmt;
  @override
  @JsonKey(ignore: true)
  _$$ReceiveStateImplCopyWith<_$ReceiveStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

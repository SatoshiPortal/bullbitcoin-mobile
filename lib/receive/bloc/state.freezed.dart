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
  ReceiveStep get step =>
      throw _privateConstructorUsedError; // required bdk.Wallet bdkWallet,
//
  Address? get defaultAddress =>
      throw _privateConstructorUsedError; // @Default('') String label,
  bool get loadingAddress => throw _privateConstructorUsedError;
  String get errLoadingAddress => throw _privateConstructorUsedError;
  bool get savingLabel => throw _privateConstructorUsedError;
  String get errSavingLabel => throw _privateConstructorUsedError;
  bool get labelSaved => throw _privateConstructorUsedError; //
  int get invoiceAmount => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get privateLabel => throw _privateConstructorUsedError;
  String get invoiceAddress => throw _privateConstructorUsedError;
  Address? get newInvoiceAddress => throw _privateConstructorUsedError;
  String get errCreatingInvoice => throw _privateConstructorUsedError;
  bool get creatingInvoice => throw _privateConstructorUsedError;

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
      {ReceiveStep step,
      Address? defaultAddress,
      bool loadingAddress,
      String errLoadingAddress,
      bool savingLabel,
      String errSavingLabel,
      bool labelSaved,
      int invoiceAmount,
      String description,
      String privateLabel,
      String invoiceAddress,
      Address? newInvoiceAddress,
      String errCreatingInvoice,
      bool creatingInvoice});

  $AddressCopyWith<$Res>? get defaultAddress;
  $AddressCopyWith<$Res>? get newInvoiceAddress;
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
    Object? step = null,
    Object? defaultAddress = freezed,
    Object? loadingAddress = null,
    Object? errLoadingAddress = null,
    Object? savingLabel = null,
    Object? errSavingLabel = null,
    Object? labelSaved = null,
    Object? invoiceAmount = null,
    Object? description = null,
    Object? privateLabel = null,
    Object? invoiceAddress = null,
    Object? newInvoiceAddress = freezed,
    Object? errCreatingInvoice = null,
    Object? creatingInvoice = null,
  }) {
    return _then(_value.copyWith(
      step: null == step
          ? _value.step
          : step // ignore: cast_nullable_to_non_nullable
              as ReceiveStep,
      defaultAddress: freezed == defaultAddress
          ? _value.defaultAddress
          : defaultAddress // ignore: cast_nullable_to_non_nullable
              as Address?,
      loadingAddress: null == loadingAddress
          ? _value.loadingAddress
          : loadingAddress // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingAddress: null == errLoadingAddress
          ? _value.errLoadingAddress
          : errLoadingAddress // ignore: cast_nullable_to_non_nullable
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
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      privateLabel: null == privateLabel
          ? _value.privateLabel
          : privateLabel // ignore: cast_nullable_to_non_nullable
              as String,
      invoiceAddress: null == invoiceAddress
          ? _value.invoiceAddress
          : invoiceAddress // ignore: cast_nullable_to_non_nullable
              as String,
      newInvoiceAddress: freezed == newInvoiceAddress
          ? _value.newInvoiceAddress
          : newInvoiceAddress // ignore: cast_nullable_to_non_nullable
              as Address?,
      errCreatingInvoice: null == errCreatingInvoice
          ? _value.errCreatingInvoice
          : errCreatingInvoice // ignore: cast_nullable_to_non_nullable
              as String,
      creatingInvoice: null == creatingInvoice
          ? _value.creatingInvoice
          : creatingInvoice // ignore: cast_nullable_to_non_nullable
              as bool,
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
  $AddressCopyWith<$Res>? get newInvoiceAddress {
    if (_value.newInvoiceAddress == null) {
      return null;
    }

    return $AddressCopyWith<$Res>(_value.newInvoiceAddress!, (value) {
      return _then(_value.copyWith(newInvoiceAddress: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$_ReceiveStateCopyWith<$Res>
    implements $ReceiveStateCopyWith<$Res> {
  factory _$$_ReceiveStateCopyWith(
          _$_ReceiveState value, $Res Function(_$_ReceiveState) then) =
      __$$_ReceiveStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {ReceiveStep step,
      Address? defaultAddress,
      bool loadingAddress,
      String errLoadingAddress,
      bool savingLabel,
      String errSavingLabel,
      bool labelSaved,
      int invoiceAmount,
      String description,
      String privateLabel,
      String invoiceAddress,
      Address? newInvoiceAddress,
      String errCreatingInvoice,
      bool creatingInvoice});

  @override
  $AddressCopyWith<$Res>? get defaultAddress;
  @override
  $AddressCopyWith<$Res>? get newInvoiceAddress;
}

/// @nodoc
class __$$_ReceiveStateCopyWithImpl<$Res>
    extends _$ReceiveStateCopyWithImpl<$Res, _$_ReceiveState>
    implements _$$_ReceiveStateCopyWith<$Res> {
  __$$_ReceiveStateCopyWithImpl(
      _$_ReceiveState _value, $Res Function(_$_ReceiveState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? step = null,
    Object? defaultAddress = freezed,
    Object? loadingAddress = null,
    Object? errLoadingAddress = null,
    Object? savingLabel = null,
    Object? errSavingLabel = null,
    Object? labelSaved = null,
    Object? invoiceAmount = null,
    Object? description = null,
    Object? privateLabel = null,
    Object? invoiceAddress = null,
    Object? newInvoiceAddress = freezed,
    Object? errCreatingInvoice = null,
    Object? creatingInvoice = null,
  }) {
    return _then(_$_ReceiveState(
      step: null == step
          ? _value.step
          : step // ignore: cast_nullable_to_non_nullable
              as ReceiveStep,
      defaultAddress: freezed == defaultAddress
          ? _value.defaultAddress
          : defaultAddress // ignore: cast_nullable_to_non_nullable
              as Address?,
      loadingAddress: null == loadingAddress
          ? _value.loadingAddress
          : loadingAddress // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingAddress: null == errLoadingAddress
          ? _value.errLoadingAddress
          : errLoadingAddress // ignore: cast_nullable_to_non_nullable
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
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      privateLabel: null == privateLabel
          ? _value.privateLabel
          : privateLabel // ignore: cast_nullable_to_non_nullable
              as String,
      invoiceAddress: null == invoiceAddress
          ? _value.invoiceAddress
          : invoiceAddress // ignore: cast_nullable_to_non_nullable
              as String,
      newInvoiceAddress: freezed == newInvoiceAddress
          ? _value.newInvoiceAddress
          : newInvoiceAddress // ignore: cast_nullable_to_non_nullable
              as Address?,
      errCreatingInvoice: null == errCreatingInvoice
          ? _value.errCreatingInvoice
          : errCreatingInvoice // ignore: cast_nullable_to_non_nullable
              as String,
      creatingInvoice: null == creatingInvoice
          ? _value.creatingInvoice
          : creatingInvoice // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$_ReceiveState extends _ReceiveState {
  const _$_ReceiveState(
      {this.step = ReceiveStep.defaultAddress,
      this.defaultAddress,
      this.loadingAddress = true,
      this.errLoadingAddress = '',
      this.savingLabel = false,
      this.errSavingLabel = '',
      this.labelSaved = false,
      this.invoiceAmount = 0,
      this.description = '',
      this.privateLabel = '',
      this.invoiceAddress = '',
      this.newInvoiceAddress,
      this.errCreatingInvoice = '',
      this.creatingInvoice = true})
      : super._();

  @override
  @JsonKey()
  final ReceiveStep step;
// required bdk.Wallet bdkWallet,
//
  @override
  final Address? defaultAddress;
// @Default('') String label,
  @override
  @JsonKey()
  final bool loadingAddress;
  @override
  @JsonKey()
  final String errLoadingAddress;
  @override
  @JsonKey()
  final bool savingLabel;
  @override
  @JsonKey()
  final String errSavingLabel;
  @override
  @JsonKey()
  final bool labelSaved;
//
  @override
  @JsonKey()
  final int invoiceAmount;
  @override
  @JsonKey()
  final String description;
  @override
  @JsonKey()
  final String privateLabel;
  @override
  @JsonKey()
  final String invoiceAddress;
  @override
  final Address? newInvoiceAddress;
  @override
  @JsonKey()
  final String errCreatingInvoice;
  @override
  @JsonKey()
  final bool creatingInvoice;

  @override
  String toString() {
    return 'ReceiveState(step: $step, defaultAddress: $defaultAddress, loadingAddress: $loadingAddress, errLoadingAddress: $errLoadingAddress, savingLabel: $savingLabel, errSavingLabel: $errSavingLabel, labelSaved: $labelSaved, invoiceAmount: $invoiceAmount, description: $description, privateLabel: $privateLabel, invoiceAddress: $invoiceAddress, newInvoiceAddress: $newInvoiceAddress, errCreatingInvoice: $errCreatingInvoice, creatingInvoice: $creatingInvoice)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_ReceiveState &&
            (identical(other.step, step) || other.step == step) &&
            (identical(other.defaultAddress, defaultAddress) ||
                other.defaultAddress == defaultAddress) &&
            (identical(other.loadingAddress, loadingAddress) ||
                other.loadingAddress == loadingAddress) &&
            (identical(other.errLoadingAddress, errLoadingAddress) ||
                other.errLoadingAddress == errLoadingAddress) &&
            (identical(other.savingLabel, savingLabel) ||
                other.savingLabel == savingLabel) &&
            (identical(other.errSavingLabel, errSavingLabel) ||
                other.errSavingLabel == errSavingLabel) &&
            (identical(other.labelSaved, labelSaved) ||
                other.labelSaved == labelSaved) &&
            (identical(other.invoiceAmount, invoiceAmount) ||
                other.invoiceAmount == invoiceAmount) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.privateLabel, privateLabel) ||
                other.privateLabel == privateLabel) &&
            (identical(other.invoiceAddress, invoiceAddress) ||
                other.invoiceAddress == invoiceAddress) &&
            (identical(other.newInvoiceAddress, newInvoiceAddress) ||
                other.newInvoiceAddress == newInvoiceAddress) &&
            (identical(other.errCreatingInvoice, errCreatingInvoice) ||
                other.errCreatingInvoice == errCreatingInvoice) &&
            (identical(other.creatingInvoice, creatingInvoice) ||
                other.creatingInvoice == creatingInvoice));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      step,
      defaultAddress,
      loadingAddress,
      errLoadingAddress,
      savingLabel,
      errSavingLabel,
      labelSaved,
      invoiceAmount,
      description,
      privateLabel,
      invoiceAddress,
      newInvoiceAddress,
      errCreatingInvoice,
      creatingInvoice);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_ReceiveStateCopyWith<_$_ReceiveState> get copyWith =>
      __$$_ReceiveStateCopyWithImpl<_$_ReceiveState>(this, _$identity);
}

abstract class _ReceiveState extends ReceiveState {
  const factory _ReceiveState(
      {final ReceiveStep step,
      final Address? defaultAddress,
      final bool loadingAddress,
      final String errLoadingAddress,
      final bool savingLabel,
      final String errSavingLabel,
      final bool labelSaved,
      final int invoiceAmount,
      final String description,
      final String privateLabel,
      final String invoiceAddress,
      final Address? newInvoiceAddress,
      final String errCreatingInvoice,
      final bool creatingInvoice}) = _$_ReceiveState;
  const _ReceiveState._() : super._();

  @override
  ReceiveStep get step;
  @override // required bdk.Wallet bdkWallet,
//
  Address? get defaultAddress;
  @override // @Default('') String label,
  bool get loadingAddress;
  @override
  String get errLoadingAddress;
  @override
  bool get savingLabel;
  @override
  String get errSavingLabel;
  @override
  bool get labelSaved;
  @override //
  int get invoiceAmount;
  @override
  String get description;
  @override
  String get privateLabel;
  @override
  String get invoiceAddress;
  @override
  Address? get newInvoiceAddress;
  @override
  String get errCreatingInvoice;
  @override
  bool get creatingInvoice;
  @override
  @JsonKey(ignore: true)
  _$$_ReceiveStateCopyWith<_$_ReceiveState> get copyWith =>
      throw _privateConstructorUsedError;
}

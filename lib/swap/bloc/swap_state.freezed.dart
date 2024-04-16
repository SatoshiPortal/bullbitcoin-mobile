// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'swap_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$SwapState {
  bool get creatingInvoice => throw _privateConstructorUsedError;
  String get errCreatingInvoice => throw _privateConstructorUsedError;
  String get errCreatingSwapInv => throw _privateConstructorUsedError;
  bool get generatingSwapInv => throw _privateConstructorUsedError;
  SwapTx? get swapTx => throw _privateConstructorUsedError;
  Invoice? get invoice => throw _privateConstructorUsedError;
  bool get errSmallAmt => throw _privateConstructorUsedError;
  int? get errHighFees => throw _privateConstructorUsedError;
  Wallet? get updatedWallet => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $SwapStateCopyWith<SwapState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SwapStateCopyWith<$Res> {
  factory $SwapStateCopyWith(SwapState value, $Res Function(SwapState) then) =
      _$SwapStateCopyWithImpl<$Res, SwapState>;
  @useResult
  $Res call(
      {bool creatingInvoice,
      String errCreatingInvoice,
      String errCreatingSwapInv,
      bool generatingSwapInv,
      SwapTx? swapTx,
      Invoice? invoice,
      bool errSmallAmt,
      int? errHighFees,
      Wallet? updatedWallet});

  $SwapTxCopyWith<$Res>? get swapTx;
  $InvoiceCopyWith<$Res>? get invoice;
  $WalletCopyWith<$Res>? get updatedWallet;
}

/// @nodoc
class _$SwapStateCopyWithImpl<$Res, $Val extends SwapState>
    implements $SwapStateCopyWith<$Res> {
  _$SwapStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? creatingInvoice = null,
    Object? errCreatingInvoice = null,
    Object? errCreatingSwapInv = null,
    Object? generatingSwapInv = null,
    Object? swapTx = freezed,
    Object? invoice = freezed,
    Object? errSmallAmt = null,
    Object? errHighFees = freezed,
    Object? updatedWallet = freezed,
  }) {
    return _then(_value.copyWith(
      creatingInvoice: null == creatingInvoice
          ? _value.creatingInvoice
          : creatingInvoice // ignore: cast_nullable_to_non_nullable
              as bool,
      errCreatingInvoice: null == errCreatingInvoice
          ? _value.errCreatingInvoice
          : errCreatingInvoice // ignore: cast_nullable_to_non_nullable
              as String,
      errCreatingSwapInv: null == errCreatingSwapInv
          ? _value.errCreatingSwapInv
          : errCreatingSwapInv // ignore: cast_nullable_to_non_nullable
              as String,
      generatingSwapInv: null == generatingSwapInv
          ? _value.generatingSwapInv
          : generatingSwapInv // ignore: cast_nullable_to_non_nullable
              as bool,
      swapTx: freezed == swapTx
          ? _value.swapTx
          : swapTx // ignore: cast_nullable_to_non_nullable
              as SwapTx?,
      invoice: freezed == invoice
          ? _value.invoice
          : invoice // ignore: cast_nullable_to_non_nullable
              as Invoice?,
      errSmallAmt: null == errSmallAmt
          ? _value.errSmallAmt
          : errSmallAmt // ignore: cast_nullable_to_non_nullable
              as bool,
      errHighFees: freezed == errHighFees
          ? _value.errHighFees
          : errHighFees // ignore: cast_nullable_to_non_nullable
              as int?,
      updatedWallet: freezed == updatedWallet
          ? _value.updatedWallet
          : updatedWallet // ignore: cast_nullable_to_non_nullable
              as Wallet?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $SwapTxCopyWith<$Res>? get swapTx {
    if (_value.swapTx == null) {
      return null;
    }

    return $SwapTxCopyWith<$Res>(_value.swapTx!, (value) {
      return _then(_value.copyWith(swapTx: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $InvoiceCopyWith<$Res>? get invoice {
    if (_value.invoice == null) {
      return null;
    }

    return $InvoiceCopyWith<$Res>(_value.invoice!, (value) {
      return _then(_value.copyWith(invoice: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $WalletCopyWith<$Res>? get updatedWallet {
    if (_value.updatedWallet == null) {
      return null;
    }

    return $WalletCopyWith<$Res>(_value.updatedWallet!, (value) {
      return _then(_value.copyWith(updatedWallet: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SwapStateImplCopyWith<$Res>
    implements $SwapStateCopyWith<$Res> {
  factory _$$SwapStateImplCopyWith(
          _$SwapStateImpl value, $Res Function(_$SwapStateImpl) then) =
      __$$SwapStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool creatingInvoice,
      String errCreatingInvoice,
      String errCreatingSwapInv,
      bool generatingSwapInv,
      SwapTx? swapTx,
      Invoice? invoice,
      bool errSmallAmt,
      int? errHighFees,
      Wallet? updatedWallet});

  @override
  $SwapTxCopyWith<$Res>? get swapTx;
  @override
  $InvoiceCopyWith<$Res>? get invoice;
  @override
  $WalletCopyWith<$Res>? get updatedWallet;
}

/// @nodoc
class __$$SwapStateImplCopyWithImpl<$Res>
    extends _$SwapStateCopyWithImpl<$Res, _$SwapStateImpl>
    implements _$$SwapStateImplCopyWith<$Res> {
  __$$SwapStateImplCopyWithImpl(
      _$SwapStateImpl _value, $Res Function(_$SwapStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? creatingInvoice = null,
    Object? errCreatingInvoice = null,
    Object? errCreatingSwapInv = null,
    Object? generatingSwapInv = null,
    Object? swapTx = freezed,
    Object? invoice = freezed,
    Object? errSmallAmt = null,
    Object? errHighFees = freezed,
    Object? updatedWallet = freezed,
  }) {
    return _then(_$SwapStateImpl(
      creatingInvoice: null == creatingInvoice
          ? _value.creatingInvoice
          : creatingInvoice // ignore: cast_nullable_to_non_nullable
              as bool,
      errCreatingInvoice: null == errCreatingInvoice
          ? _value.errCreatingInvoice
          : errCreatingInvoice // ignore: cast_nullable_to_non_nullable
              as String,
      errCreatingSwapInv: null == errCreatingSwapInv
          ? _value.errCreatingSwapInv
          : errCreatingSwapInv // ignore: cast_nullable_to_non_nullable
              as String,
      generatingSwapInv: null == generatingSwapInv
          ? _value.generatingSwapInv
          : generatingSwapInv // ignore: cast_nullable_to_non_nullable
              as bool,
      swapTx: freezed == swapTx
          ? _value.swapTx
          : swapTx // ignore: cast_nullable_to_non_nullable
              as SwapTx?,
      invoice: freezed == invoice
          ? _value.invoice
          : invoice // ignore: cast_nullable_to_non_nullable
              as Invoice?,
      errSmallAmt: null == errSmallAmt
          ? _value.errSmallAmt
          : errSmallAmt // ignore: cast_nullable_to_non_nullable
              as bool,
      errHighFees: freezed == errHighFees
          ? _value.errHighFees
          : errHighFees // ignore: cast_nullable_to_non_nullable
              as int?,
      updatedWallet: freezed == updatedWallet
          ? _value.updatedWallet
          : updatedWallet // ignore: cast_nullable_to_non_nullable
              as Wallet?,
    ));
  }
}

/// @nodoc

class _$SwapStateImpl extends _SwapState {
  const _$SwapStateImpl(
      {this.creatingInvoice = false,
      this.errCreatingInvoice = '',
      this.errCreatingSwapInv = '',
      this.generatingSwapInv = false,
      this.swapTx,
      this.invoice,
      this.errSmallAmt = false,
      this.errHighFees,
      this.updatedWallet})
      : super._();

  @override
  @JsonKey()
  final bool creatingInvoice;
  @override
  @JsonKey()
  final String errCreatingInvoice;
  @override
  @JsonKey()
  final String errCreatingSwapInv;
  @override
  @JsonKey()
  final bool generatingSwapInv;
  @override
  final SwapTx? swapTx;
  @override
  final Invoice? invoice;
  @override
  @JsonKey()
  final bool errSmallAmt;
  @override
  final int? errHighFees;
  @override
  final Wallet? updatedWallet;

  @override
  String toString() {
    return 'SwapState(creatingInvoice: $creatingInvoice, errCreatingInvoice: $errCreatingInvoice, errCreatingSwapInv: $errCreatingSwapInv, generatingSwapInv: $generatingSwapInv, swapTx: $swapTx, invoice: $invoice, errSmallAmt: $errSmallAmt, errHighFees: $errHighFees, updatedWallet: $updatedWallet)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SwapStateImpl &&
            (identical(other.creatingInvoice, creatingInvoice) ||
                other.creatingInvoice == creatingInvoice) &&
            (identical(other.errCreatingInvoice, errCreatingInvoice) ||
                other.errCreatingInvoice == errCreatingInvoice) &&
            (identical(other.errCreatingSwapInv, errCreatingSwapInv) ||
                other.errCreatingSwapInv == errCreatingSwapInv) &&
            (identical(other.generatingSwapInv, generatingSwapInv) ||
                other.generatingSwapInv == generatingSwapInv) &&
            (identical(other.swapTx, swapTx) || other.swapTx == swapTx) &&
            (identical(other.invoice, invoice) || other.invoice == invoice) &&
            (identical(other.errSmallAmt, errSmallAmt) ||
                other.errSmallAmt == errSmallAmt) &&
            (identical(other.errHighFees, errHighFees) ||
                other.errHighFees == errHighFees) &&
            (identical(other.updatedWallet, updatedWallet) ||
                other.updatedWallet == updatedWallet));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      creatingInvoice,
      errCreatingInvoice,
      errCreatingSwapInv,
      generatingSwapInv,
      swapTx,
      invoice,
      errSmallAmt,
      errHighFees,
      updatedWallet);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SwapStateImplCopyWith<_$SwapStateImpl> get copyWith =>
      __$$SwapStateImplCopyWithImpl<_$SwapStateImpl>(this, _$identity);
}

abstract class _SwapState extends SwapState {
  const factory _SwapState(
      {final bool creatingInvoice,
      final String errCreatingInvoice,
      final String errCreatingSwapInv,
      final bool generatingSwapInv,
      final SwapTx? swapTx,
      final Invoice? invoice,
      final bool errSmallAmt,
      final int? errHighFees,
      final Wallet? updatedWallet}) = _$SwapStateImpl;
  const _SwapState._() : super._();

  @override
  bool get creatingInvoice;
  @override
  String get errCreatingInvoice;
  @override
  String get errCreatingSwapInv;
  @override
  bool get generatingSwapInv;
  @override
  SwapTx? get swapTx;
  @override
  Invoice? get invoice;
  @override
  bool get errSmallAmt;
  @override
  int? get errHighFees;
  @override
  Wallet? get updatedWallet;
  @override
  @JsonKey(ignore: true)
  _$$SwapStateImplCopyWith<_$SwapStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

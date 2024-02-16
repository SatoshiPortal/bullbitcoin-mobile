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

/// @nodoc
mixin _$ReceiveState {
  bool get loadingAddress => throw _privateConstructorUsedError;
  String get errLoadingAddress => throw _privateConstructorUsedError;
  Address? get defaultAddress => throw _privateConstructorUsedError;
  String get privateLabel => throw _privateConstructorUsedError;
  bool get savingLabel => throw _privateConstructorUsedError;
  String get errSavingLabel => throw _privateConstructorUsedError;
  bool get labelSaved => throw _privateConstructorUsedError;
  int get savedInvoiceAmount => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get savedDescription => throw _privateConstructorUsedError;
  bool get creatingInvoice => throw _privateConstructorUsedError;
  String get errCreatingInvoice => throw _privateConstructorUsedError;
  WalletBloc? get walletBloc => throw _privateConstructorUsedError;
  ReceiveWalletType get walletType => throw _privateConstructorUsedError;
  String get errCreatingSwapInv => throw _privateConstructorUsedError;
  bool get generatingSwapInv => throw _privateConstructorUsedError;
  String get errClaimingSwap => throw _privateConstructorUsedError;
  bool get claimingSwapSwap => throw _privateConstructorUsedError;
  SwapTx? get swapTx => throw _privateConstructorUsedError;
  List<Transaction>? get swapTxs => throw _privateConstructorUsedError;

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
      int savedInvoiceAmount,
      String description,
      String savedDescription,
      bool creatingInvoice,
      String errCreatingInvoice,
      WalletBloc? walletBloc,
      ReceiveWalletType walletType,
      String errCreatingSwapInv,
      bool generatingSwapInv,
      String errClaimingSwap,
      bool claimingSwapSwap,
      SwapTx? swapTx,
      List<Transaction>? swapTxs});

  $AddressCopyWith<$Res>? get defaultAddress;
  $SwapTxCopyWith<$Res>? get swapTx;
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
    Object? savedInvoiceAmount = null,
    Object? description = null,
    Object? savedDescription = null,
    Object? creatingInvoice = null,
    Object? errCreatingInvoice = null,
    Object? walletBloc = freezed,
    Object? walletType = null,
    Object? errCreatingSwapInv = null,
    Object? generatingSwapInv = null,
    Object? errClaimingSwap = null,
    Object? claimingSwapSwap = null,
    Object? swapTx = freezed,
    Object? swapTxs = freezed,
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
      walletBloc: freezed == walletBloc
          ? _value.walletBloc
          : walletBloc // ignore: cast_nullable_to_non_nullable
              as WalletBloc?,
      walletType: null == walletType
          ? _value.walletType
          : walletType // ignore: cast_nullable_to_non_nullable
              as ReceiveWalletType,
      errCreatingSwapInv: null == errCreatingSwapInv
          ? _value.errCreatingSwapInv
          : errCreatingSwapInv // ignore: cast_nullable_to_non_nullable
              as String,
      generatingSwapInv: null == generatingSwapInv
          ? _value.generatingSwapInv
          : generatingSwapInv // ignore: cast_nullable_to_non_nullable
              as bool,
      errClaimingSwap: null == errClaimingSwap
          ? _value.errClaimingSwap
          : errClaimingSwap // ignore: cast_nullable_to_non_nullable
              as String,
      claimingSwapSwap: null == claimingSwapSwap
          ? _value.claimingSwapSwap
          : claimingSwapSwap // ignore: cast_nullable_to_non_nullable
              as bool,
      swapTx: freezed == swapTx
          ? _value.swapTx
          : swapTx // ignore: cast_nullable_to_non_nullable
              as SwapTx?,
      swapTxs: freezed == swapTxs
          ? _value.swapTxs
          : swapTxs // ignore: cast_nullable_to_non_nullable
              as List<Transaction>?,
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
  $SwapTxCopyWith<$Res>? get swapTx {
    if (_value.swapTx == null) {
      return null;
    }

    return $SwapTxCopyWith<$Res>(_value.swapTx!, (value) {
      return _then(_value.copyWith(swapTx: value) as $Val);
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
      int savedInvoiceAmount,
      String description,
      String savedDescription,
      bool creatingInvoice,
      String errCreatingInvoice,
      WalletBloc? walletBloc,
      ReceiveWalletType walletType,
      String errCreatingSwapInv,
      bool generatingSwapInv,
      String errClaimingSwap,
      bool claimingSwapSwap,
      SwapTx? swapTx,
      List<Transaction>? swapTxs});

  @override
  $AddressCopyWith<$Res>? get defaultAddress;
  @override
  $SwapTxCopyWith<$Res>? get swapTx;
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
    Object? savedInvoiceAmount = null,
    Object? description = null,
    Object? savedDescription = null,
    Object? creatingInvoice = null,
    Object? errCreatingInvoice = null,
    Object? walletBloc = freezed,
    Object? walletType = null,
    Object? errCreatingSwapInv = null,
    Object? generatingSwapInv = null,
    Object? errClaimingSwap = null,
    Object? claimingSwapSwap = null,
    Object? swapTx = freezed,
    Object? swapTxs = freezed,
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
      walletBloc: freezed == walletBloc
          ? _value.walletBloc
          : walletBloc // ignore: cast_nullable_to_non_nullable
              as WalletBloc?,
      walletType: null == walletType
          ? _value.walletType
          : walletType // ignore: cast_nullable_to_non_nullable
              as ReceiveWalletType,
      errCreatingSwapInv: null == errCreatingSwapInv
          ? _value.errCreatingSwapInv
          : errCreatingSwapInv // ignore: cast_nullable_to_non_nullable
              as String,
      generatingSwapInv: null == generatingSwapInv
          ? _value.generatingSwapInv
          : generatingSwapInv // ignore: cast_nullable_to_non_nullable
              as bool,
      errClaimingSwap: null == errClaimingSwap
          ? _value.errClaimingSwap
          : errClaimingSwap // ignore: cast_nullable_to_non_nullable
              as String,
      claimingSwapSwap: null == claimingSwapSwap
          ? _value.claimingSwapSwap
          : claimingSwapSwap // ignore: cast_nullable_to_non_nullable
              as bool,
      swapTx: freezed == swapTx
          ? _value.swapTx
          : swapTx // ignore: cast_nullable_to_non_nullable
              as SwapTx?,
      swapTxs: freezed == swapTxs
          ? _value._swapTxs
          : swapTxs // ignore: cast_nullable_to_non_nullable
              as List<Transaction>?,
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
      this.savedInvoiceAmount = 0,
      this.description = '',
      this.savedDescription = '',
      this.creatingInvoice = true,
      this.errCreatingInvoice = '',
      this.walletBloc,
      this.walletType = ReceiveWalletType.secure,
      this.errCreatingSwapInv = '',
      this.generatingSwapInv = false,
      this.errClaimingSwap = '',
      this.claimingSwapSwap = false,
      this.swapTx,
      final List<Transaction>? swapTxs})
      : _swapTxs = swapTxs,
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
  @override
  final WalletBloc? walletBloc;
  @override
  @JsonKey()
  final ReceiveWalletType walletType;
  @override
  @JsonKey()
  final String errCreatingSwapInv;
  @override
  @JsonKey()
  final bool generatingSwapInv;
  @override
  @JsonKey()
  final String errClaimingSwap;
  @override
  @JsonKey()
  final bool claimingSwapSwap;
  @override
  final SwapTx? swapTx;
  final List<Transaction>? _swapTxs;
  @override
  List<Transaction>? get swapTxs {
    final value = _swapTxs;
    if (value == null) return null;
    if (_swapTxs is EqualUnmodifiableListView) return _swapTxs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'ReceiveState(loadingAddress: $loadingAddress, errLoadingAddress: $errLoadingAddress, defaultAddress: $defaultAddress, privateLabel: $privateLabel, savingLabel: $savingLabel, errSavingLabel: $errSavingLabel, labelSaved: $labelSaved, savedInvoiceAmount: $savedInvoiceAmount, description: $description, savedDescription: $savedDescription, creatingInvoice: $creatingInvoice, errCreatingInvoice: $errCreatingInvoice, walletBloc: $walletBloc, walletType: $walletType, errCreatingSwapInv: $errCreatingSwapInv, generatingSwapInv: $generatingSwapInv, errClaimingSwap: $errClaimingSwap, claimingSwapSwap: $claimingSwapSwap, swapTx: $swapTx, swapTxs: $swapTxs)';
  }

  @override
  bool operator ==(Object other) {
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
            (identical(other.walletBloc, walletBloc) ||
                other.walletBloc == walletBloc) &&
            (identical(other.walletType, walletType) ||
                other.walletType == walletType) &&
            (identical(other.errCreatingSwapInv, errCreatingSwapInv) ||
                other.errCreatingSwapInv == errCreatingSwapInv) &&
            (identical(other.generatingSwapInv, generatingSwapInv) ||
                other.generatingSwapInv == generatingSwapInv) &&
            (identical(other.errClaimingSwap, errClaimingSwap) ||
                other.errClaimingSwap == errClaimingSwap) &&
            (identical(other.claimingSwapSwap, claimingSwapSwap) ||
                other.claimingSwapSwap == claimingSwapSwap) &&
            (identical(other.swapTx, swapTx) || other.swapTx == swapTx) &&
            const DeepCollectionEquality().equals(other._swapTxs, _swapTxs));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        loadingAddress,
        errLoadingAddress,
        defaultAddress,
        privateLabel,
        savingLabel,
        errSavingLabel,
        labelSaved,
        savedInvoiceAmount,
        description,
        savedDescription,
        creatingInvoice,
        errCreatingInvoice,
        walletBloc,
        walletType,
        errCreatingSwapInv,
        generatingSwapInv,
        errClaimingSwap,
        claimingSwapSwap,
        swapTx,
        const DeepCollectionEquality().hash(_swapTxs)
      ]);

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
      final int savedInvoiceAmount,
      final String description,
      final String savedDescription,
      final bool creatingInvoice,
      final String errCreatingInvoice,
      final WalletBloc? walletBloc,
      final ReceiveWalletType walletType,
      final String errCreatingSwapInv,
      final bool generatingSwapInv,
      final String errClaimingSwap,
      final bool claimingSwapSwap,
      final SwapTx? swapTx,
      final List<Transaction>? swapTxs}) = _$ReceiveStateImpl;
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
  int get savedInvoiceAmount;
  @override
  String get description;
  @override
  String get savedDescription;
  @override
  bool get creatingInvoice;
  @override
  String get errCreatingInvoice;
  @override
  WalletBloc? get walletBloc;
  @override
  ReceiveWalletType get walletType;
  @override
  String get errCreatingSwapInv;
  @override
  bool get generatingSwapInv;
  @override
  String get errClaimingSwap;
  @override
  bool get claimingSwapSwap;
  @override
  SwapTx? get swapTx;
  @override
  List<Transaction>? get swapTxs;
  @override
  @JsonKey(ignore: true)
  _$$ReceiveStateImplCopyWith<_$ReceiveStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

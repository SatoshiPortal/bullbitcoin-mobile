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
mixin _$WalletState {
  Wallet? get wallet => throw _privateConstructorUsedError;
  bdk.Wallet? get bdkWallet =>
      throw _privateConstructorUsedError; // List<Transaction>? txs,
// Balance? balance,
  String get name => throw _privateConstructorUsedError;
  bool get loadingWallet => throw _privateConstructorUsedError;
  String get errLoadingWallet => throw _privateConstructorUsedError;
  bool get loadingTxs => throw _privateConstructorUsedError;
  String get errLoadingTxs => throw _privateConstructorUsedError;
  bool get loadingBalance => throw _privateConstructorUsedError;
  String get errLoadingBalance => throw _privateConstructorUsedError;
  bool get syncing => throw _privateConstructorUsedError;
  String get errSyncing => throw _privateConstructorUsedError;
  bool get syncingAddresses => throw _privateConstructorUsedError;
  String get errSyncingAddresses => throw _privateConstructorUsedError;
  bool get savingName => throw _privateConstructorUsedError;
  String get errSavingName => throw _privateConstructorUsedError;
  int get syncErrCount =>
      throw _privateConstructorUsedError; // Address? newAddress,
  Address? get firstAddress => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $WalletStateCopyWith<WalletState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WalletStateCopyWith<$Res> {
  factory $WalletStateCopyWith(
          WalletState value, $Res Function(WalletState) then) =
      _$WalletStateCopyWithImpl<$Res, WalletState>;
  @useResult
  $Res call(
      {Wallet? wallet,
      bdk.Wallet? bdkWallet,
      String name,
      bool loadingWallet,
      String errLoadingWallet,
      bool loadingTxs,
      String errLoadingTxs,
      bool loadingBalance,
      String errLoadingBalance,
      bool syncing,
      String errSyncing,
      bool syncingAddresses,
      String errSyncingAddresses,
      bool savingName,
      String errSavingName,
      int syncErrCount,
      Address? firstAddress});

  $WalletCopyWith<$Res>? get wallet;
  $AddressCopyWith<$Res>? get firstAddress;
}

/// @nodoc
class _$WalletStateCopyWithImpl<$Res, $Val extends WalletState>
    implements $WalletStateCopyWith<$Res> {
  _$WalletStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? wallet = freezed,
    Object? bdkWallet = freezed,
    Object? name = null,
    Object? loadingWallet = null,
    Object? errLoadingWallet = null,
    Object? loadingTxs = null,
    Object? errLoadingTxs = null,
    Object? loadingBalance = null,
    Object? errLoadingBalance = null,
    Object? syncing = null,
    Object? errSyncing = null,
    Object? syncingAddresses = null,
    Object? errSyncingAddresses = null,
    Object? savingName = null,
    Object? errSavingName = null,
    Object? syncErrCount = null,
    Object? firstAddress = freezed,
  }) {
    return _then(_value.copyWith(
      wallet: freezed == wallet
          ? _value.wallet
          : wallet // ignore: cast_nullable_to_non_nullable
              as Wallet?,
      bdkWallet: freezed == bdkWallet
          ? _value.bdkWallet
          : bdkWallet // ignore: cast_nullable_to_non_nullable
              as bdk.Wallet?,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      loadingWallet: null == loadingWallet
          ? _value.loadingWallet
          : loadingWallet // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingWallet: null == errLoadingWallet
          ? _value.errLoadingWallet
          : errLoadingWallet // ignore: cast_nullable_to_non_nullable
              as String,
      loadingTxs: null == loadingTxs
          ? _value.loadingTxs
          : loadingTxs // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingTxs: null == errLoadingTxs
          ? _value.errLoadingTxs
          : errLoadingTxs // ignore: cast_nullable_to_non_nullable
              as String,
      loadingBalance: null == loadingBalance
          ? _value.loadingBalance
          : loadingBalance // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingBalance: null == errLoadingBalance
          ? _value.errLoadingBalance
          : errLoadingBalance // ignore: cast_nullable_to_non_nullable
              as String,
      syncing: null == syncing
          ? _value.syncing
          : syncing // ignore: cast_nullable_to_non_nullable
              as bool,
      errSyncing: null == errSyncing
          ? _value.errSyncing
          : errSyncing // ignore: cast_nullable_to_non_nullable
              as String,
      syncingAddresses: null == syncingAddresses
          ? _value.syncingAddresses
          : syncingAddresses // ignore: cast_nullable_to_non_nullable
              as bool,
      errSyncingAddresses: null == errSyncingAddresses
          ? _value.errSyncingAddresses
          : errSyncingAddresses // ignore: cast_nullable_to_non_nullable
              as String,
      savingName: null == savingName
          ? _value.savingName
          : savingName // ignore: cast_nullable_to_non_nullable
              as bool,
      errSavingName: null == errSavingName
          ? _value.errSavingName
          : errSavingName // ignore: cast_nullable_to_non_nullable
              as String,
      syncErrCount: null == syncErrCount
          ? _value.syncErrCount
          : syncErrCount // ignore: cast_nullable_to_non_nullable
              as int,
      firstAddress: freezed == firstAddress
          ? _value.firstAddress
          : firstAddress // ignore: cast_nullable_to_non_nullable
              as Address?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $WalletCopyWith<$Res>? get wallet {
    if (_value.wallet == null) {
      return null;
    }

    return $WalletCopyWith<$Res>(_value.wallet!, (value) {
      return _then(_value.copyWith(wallet: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $AddressCopyWith<$Res>? get firstAddress {
    if (_value.firstAddress == null) {
      return null;
    }

    return $AddressCopyWith<$Res>(_value.firstAddress!, (value) {
      return _then(_value.copyWith(firstAddress: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$WalletStateImplCopyWith<$Res>
    implements $WalletStateCopyWith<$Res> {
  factory _$$WalletStateImplCopyWith(
          _$WalletStateImpl value, $Res Function(_$WalletStateImpl) then) =
      __$$WalletStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Wallet? wallet,
      bdk.Wallet? bdkWallet,
      String name,
      bool loadingWallet,
      String errLoadingWallet,
      bool loadingTxs,
      String errLoadingTxs,
      bool loadingBalance,
      String errLoadingBalance,
      bool syncing,
      String errSyncing,
      bool syncingAddresses,
      String errSyncingAddresses,
      bool savingName,
      String errSavingName,
      int syncErrCount,
      Address? firstAddress});

  @override
  $WalletCopyWith<$Res>? get wallet;
  @override
  $AddressCopyWith<$Res>? get firstAddress;
}

/// @nodoc
class __$$WalletStateImplCopyWithImpl<$Res>
    extends _$WalletStateCopyWithImpl<$Res, _$WalletStateImpl>
    implements _$$WalletStateImplCopyWith<$Res> {
  __$$WalletStateImplCopyWithImpl(
      _$WalletStateImpl _value, $Res Function(_$WalletStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? wallet = freezed,
    Object? bdkWallet = freezed,
    Object? name = null,
    Object? loadingWallet = null,
    Object? errLoadingWallet = null,
    Object? loadingTxs = null,
    Object? errLoadingTxs = null,
    Object? loadingBalance = null,
    Object? errLoadingBalance = null,
    Object? syncing = null,
    Object? errSyncing = null,
    Object? syncingAddresses = null,
    Object? errSyncingAddresses = null,
    Object? savingName = null,
    Object? errSavingName = null,
    Object? syncErrCount = null,
    Object? firstAddress = freezed,
  }) {
    return _then(_$WalletStateImpl(
      wallet: freezed == wallet
          ? _value.wallet
          : wallet // ignore: cast_nullable_to_non_nullable
              as Wallet?,
      bdkWallet: freezed == bdkWallet
          ? _value.bdkWallet
          : bdkWallet // ignore: cast_nullable_to_non_nullable
              as bdk.Wallet?,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      loadingWallet: null == loadingWallet
          ? _value.loadingWallet
          : loadingWallet // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingWallet: null == errLoadingWallet
          ? _value.errLoadingWallet
          : errLoadingWallet // ignore: cast_nullable_to_non_nullable
              as String,
      loadingTxs: null == loadingTxs
          ? _value.loadingTxs
          : loadingTxs // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingTxs: null == errLoadingTxs
          ? _value.errLoadingTxs
          : errLoadingTxs // ignore: cast_nullable_to_non_nullable
              as String,
      loadingBalance: null == loadingBalance
          ? _value.loadingBalance
          : loadingBalance // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingBalance: null == errLoadingBalance
          ? _value.errLoadingBalance
          : errLoadingBalance // ignore: cast_nullable_to_non_nullable
              as String,
      syncing: null == syncing
          ? _value.syncing
          : syncing // ignore: cast_nullable_to_non_nullable
              as bool,
      errSyncing: null == errSyncing
          ? _value.errSyncing
          : errSyncing // ignore: cast_nullable_to_non_nullable
              as String,
      syncingAddresses: null == syncingAddresses
          ? _value.syncingAddresses
          : syncingAddresses // ignore: cast_nullable_to_non_nullable
              as bool,
      errSyncingAddresses: null == errSyncingAddresses
          ? _value.errSyncingAddresses
          : errSyncingAddresses // ignore: cast_nullable_to_non_nullable
              as String,
      savingName: null == savingName
          ? _value.savingName
          : savingName // ignore: cast_nullable_to_non_nullable
              as bool,
      errSavingName: null == errSavingName
          ? _value.errSavingName
          : errSavingName // ignore: cast_nullable_to_non_nullable
              as String,
      syncErrCount: null == syncErrCount
          ? _value.syncErrCount
          : syncErrCount // ignore: cast_nullable_to_non_nullable
              as int,
      firstAddress: freezed == firstAddress
          ? _value.firstAddress
          : firstAddress // ignore: cast_nullable_to_non_nullable
              as Address?,
    ));
  }
}

/// @nodoc

class _$WalletStateImpl extends _WalletState {
  const _$WalletStateImpl(
      {this.wallet,
      this.bdkWallet,
      this.name = '',
      this.loadingWallet = true,
      this.errLoadingWallet = '',
      this.loadingTxs = false,
      this.errLoadingTxs = '',
      this.loadingBalance = false,
      this.errLoadingBalance = '',
      this.syncing = false,
      this.errSyncing = '',
      this.syncingAddresses = false,
      this.errSyncingAddresses = '',
      this.savingName = false,
      this.errSavingName = '',
      this.syncErrCount = 0,
      this.firstAddress})
      : super._();

  @override
  final Wallet? wallet;
  @override
  final bdk.Wallet? bdkWallet;
// List<Transaction>? txs,
// Balance? balance,
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final bool loadingWallet;
  @override
  @JsonKey()
  final String errLoadingWallet;
  @override
  @JsonKey()
  final bool loadingTxs;
  @override
  @JsonKey()
  final String errLoadingTxs;
  @override
  @JsonKey()
  final bool loadingBalance;
  @override
  @JsonKey()
  final String errLoadingBalance;
  @override
  @JsonKey()
  final bool syncing;
  @override
  @JsonKey()
  final String errSyncing;
  @override
  @JsonKey()
  final bool syncingAddresses;
  @override
  @JsonKey()
  final String errSyncingAddresses;
  @override
  @JsonKey()
  final bool savingName;
  @override
  @JsonKey()
  final String errSavingName;
  @override
  @JsonKey()
  final int syncErrCount;
// Address? newAddress,
  @override
  final Address? firstAddress;

  @override
  String toString() {
    return 'WalletState(wallet: $wallet, bdkWallet: $bdkWallet, name: $name, loadingWallet: $loadingWallet, errLoadingWallet: $errLoadingWallet, loadingTxs: $loadingTxs, errLoadingTxs: $errLoadingTxs, loadingBalance: $loadingBalance, errLoadingBalance: $errLoadingBalance, syncing: $syncing, errSyncing: $errSyncing, syncingAddresses: $syncingAddresses, errSyncingAddresses: $errSyncingAddresses, savingName: $savingName, errSavingName: $errSavingName, syncErrCount: $syncErrCount, firstAddress: $firstAddress)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WalletStateImpl &&
            (identical(other.wallet, wallet) || other.wallet == wallet) &&
            (identical(other.bdkWallet, bdkWallet) ||
                other.bdkWallet == bdkWallet) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.loadingWallet, loadingWallet) ||
                other.loadingWallet == loadingWallet) &&
            (identical(other.errLoadingWallet, errLoadingWallet) ||
                other.errLoadingWallet == errLoadingWallet) &&
            (identical(other.loadingTxs, loadingTxs) ||
                other.loadingTxs == loadingTxs) &&
            (identical(other.errLoadingTxs, errLoadingTxs) ||
                other.errLoadingTxs == errLoadingTxs) &&
            (identical(other.loadingBalance, loadingBalance) ||
                other.loadingBalance == loadingBalance) &&
            (identical(other.errLoadingBalance, errLoadingBalance) ||
                other.errLoadingBalance == errLoadingBalance) &&
            (identical(other.syncing, syncing) || other.syncing == syncing) &&
            (identical(other.errSyncing, errSyncing) ||
                other.errSyncing == errSyncing) &&
            (identical(other.syncingAddresses, syncingAddresses) ||
                other.syncingAddresses == syncingAddresses) &&
            (identical(other.errSyncingAddresses, errSyncingAddresses) ||
                other.errSyncingAddresses == errSyncingAddresses) &&
            (identical(other.savingName, savingName) ||
                other.savingName == savingName) &&
            (identical(other.errSavingName, errSavingName) ||
                other.errSavingName == errSavingName) &&
            (identical(other.syncErrCount, syncErrCount) ||
                other.syncErrCount == syncErrCount) &&
            (identical(other.firstAddress, firstAddress) ||
                other.firstAddress == firstAddress));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      wallet,
      bdkWallet,
      name,
      loadingWallet,
      errLoadingWallet,
      loadingTxs,
      errLoadingTxs,
      loadingBalance,
      errLoadingBalance,
      syncing,
      errSyncing,
      syncingAddresses,
      errSyncingAddresses,
      savingName,
      errSavingName,
      syncErrCount,
      firstAddress);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$WalletStateImplCopyWith<_$WalletStateImpl> get copyWith =>
      __$$WalletStateImplCopyWithImpl<_$WalletStateImpl>(this, _$identity);
}

abstract class _WalletState extends WalletState {
  const factory _WalletState(
      {final Wallet? wallet,
      final bdk.Wallet? bdkWallet,
      final String name,
      final bool loadingWallet,
      final String errLoadingWallet,
      final bool loadingTxs,
      final String errLoadingTxs,
      final bool loadingBalance,
      final String errLoadingBalance,
      final bool syncing,
      final String errSyncing,
      final bool syncingAddresses,
      final String errSyncingAddresses,
      final bool savingName,
      final String errSavingName,
      final int syncErrCount,
      final Address? firstAddress}) = _$WalletStateImpl;
  const _WalletState._() : super._();

  @override
  Wallet? get wallet;
  @override
  bdk.Wallet? get bdkWallet;
  @override // List<Transaction>? txs,
// Balance? balance,
  String get name;
  @override
  bool get loadingWallet;
  @override
  String get errLoadingWallet;
  @override
  bool get loadingTxs;
  @override
  String get errLoadingTxs;
  @override
  bool get loadingBalance;
  @override
  String get errLoadingBalance;
  @override
  bool get syncing;
  @override
  String get errSyncing;
  @override
  bool get syncingAddresses;
  @override
  String get errSyncingAddresses;
  @override
  bool get savingName;
  @override
  String get errSavingName;
  @override
  int get syncErrCount;
  @override // Address? newAddress,
  Address? get firstAddress;
  @override
  @JsonKey(ignore: true)
  _$$WalletStateImplCopyWith<_$WalletStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

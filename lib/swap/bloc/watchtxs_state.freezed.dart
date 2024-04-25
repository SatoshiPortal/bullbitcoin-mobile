// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'watchtxs_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$WatchTxsState {
  String get errClaimingSwap => throw _privateConstructorUsedError;
  bool get claimingSwap => throw _privateConstructorUsedError;
  String get errWatchingInvoice => throw _privateConstructorUsedError;
  BoltzApi? get boltzWatcher => throw _privateConstructorUsedError;
  bool get isTestnet => throw _privateConstructorUsedError;
  List<String> get listeningTxs => throw _privateConstructorUsedError;
  List<String> get claimedSwapTxs => throw _privateConstructorUsedError;
  List<String> get claimingSwapTxIds => throw _privateConstructorUsedError;
  Transaction? get txPaid => throw _privateConstructorUsedError;
  Wallet? get syncWallet => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $WatchTxsStateCopyWith<WatchTxsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WatchTxsStateCopyWith<$Res> {
  factory $WatchTxsStateCopyWith(
          WatchTxsState value, $Res Function(WatchTxsState) then) =
      _$WatchTxsStateCopyWithImpl<$Res, WatchTxsState>;
  @useResult
  $Res call(
      {String errClaimingSwap,
      bool claimingSwap,
      String errWatchingInvoice,
      BoltzApi? boltzWatcher,
      bool isTestnet,
      List<String> listeningTxs,
      List<String> claimedSwapTxs,
      List<String> claimingSwapTxIds,
      Transaction? txPaid,
      Wallet? syncWallet});

  $TransactionCopyWith<$Res>? get txPaid;
  $WalletCopyWith<$Res>? get syncWallet;
}

/// @nodoc
class _$WatchTxsStateCopyWithImpl<$Res, $Val extends WatchTxsState>
    implements $WatchTxsStateCopyWith<$Res> {
  _$WatchTxsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? errClaimingSwap = null,
    Object? claimingSwap = null,
    Object? errWatchingInvoice = null,
    Object? boltzWatcher = freezed,
    Object? isTestnet = null,
    Object? listeningTxs = null,
    Object? claimedSwapTxs = null,
    Object? claimingSwapTxIds = null,
    Object? txPaid = freezed,
    Object? syncWallet = freezed,
  }) {
    return _then(_value.copyWith(
      errClaimingSwap: null == errClaimingSwap
          ? _value.errClaimingSwap
          : errClaimingSwap // ignore: cast_nullable_to_non_nullable
              as String,
      claimingSwap: null == claimingSwap
          ? _value.claimingSwap
          : claimingSwap // ignore: cast_nullable_to_non_nullable
              as bool,
      errWatchingInvoice: null == errWatchingInvoice
          ? _value.errWatchingInvoice
          : errWatchingInvoice // ignore: cast_nullable_to_non_nullable
              as String,
      boltzWatcher: freezed == boltzWatcher
          ? _value.boltzWatcher
          : boltzWatcher // ignore: cast_nullable_to_non_nullable
              as BoltzApi?,
      isTestnet: null == isTestnet
          ? _value.isTestnet
          : isTestnet // ignore: cast_nullable_to_non_nullable
              as bool,
      listeningTxs: null == listeningTxs
          ? _value.listeningTxs
          : listeningTxs // ignore: cast_nullable_to_non_nullable
              as List<String>,
      claimedSwapTxs: null == claimedSwapTxs
          ? _value.claimedSwapTxs
          : claimedSwapTxs // ignore: cast_nullable_to_non_nullable
              as List<String>,
      claimingSwapTxIds: null == claimingSwapTxIds
          ? _value.claimingSwapTxIds
          : claimingSwapTxIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      txPaid: freezed == txPaid
          ? _value.txPaid
          : txPaid // ignore: cast_nullable_to_non_nullable
              as Transaction?,
      syncWallet: freezed == syncWallet
          ? _value.syncWallet
          : syncWallet // ignore: cast_nullable_to_non_nullable
              as Wallet?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $TransactionCopyWith<$Res>? get txPaid {
    if (_value.txPaid == null) {
      return null;
    }

    return $TransactionCopyWith<$Res>(_value.txPaid!, (value) {
      return _then(_value.copyWith(txPaid: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $WalletCopyWith<$Res>? get syncWallet {
    if (_value.syncWallet == null) {
      return null;
    }

    return $WalletCopyWith<$Res>(_value.syncWallet!, (value) {
      return _then(_value.copyWith(syncWallet: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$WatchTxsStateImplCopyWith<$Res>
    implements $WatchTxsStateCopyWith<$Res> {
  factory _$$WatchTxsStateImplCopyWith(
          _$WatchTxsStateImpl value, $Res Function(_$WatchTxsStateImpl) then) =
      __$$WatchTxsStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String errClaimingSwap,
      bool claimingSwap,
      String errWatchingInvoice,
      BoltzApi? boltzWatcher,
      bool isTestnet,
      List<String> listeningTxs,
      List<String> claimedSwapTxs,
      List<String> claimingSwapTxIds,
      Transaction? txPaid,
      Wallet? syncWallet});

  @override
  $TransactionCopyWith<$Res>? get txPaid;
  @override
  $WalletCopyWith<$Res>? get syncWallet;
}

/// @nodoc
class __$$WatchTxsStateImplCopyWithImpl<$Res>
    extends _$WatchTxsStateCopyWithImpl<$Res, _$WatchTxsStateImpl>
    implements _$$WatchTxsStateImplCopyWith<$Res> {
  __$$WatchTxsStateImplCopyWithImpl(
      _$WatchTxsStateImpl _value, $Res Function(_$WatchTxsStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? errClaimingSwap = null,
    Object? claimingSwap = null,
    Object? errWatchingInvoice = null,
    Object? boltzWatcher = freezed,
    Object? isTestnet = null,
    Object? listeningTxs = null,
    Object? claimedSwapTxs = null,
    Object? claimingSwapTxIds = null,
    Object? txPaid = freezed,
    Object? syncWallet = freezed,
  }) {
    return _then(_$WatchTxsStateImpl(
      errClaimingSwap: null == errClaimingSwap
          ? _value.errClaimingSwap
          : errClaimingSwap // ignore: cast_nullable_to_non_nullable
              as String,
      claimingSwap: null == claimingSwap
          ? _value.claimingSwap
          : claimingSwap // ignore: cast_nullable_to_non_nullable
              as bool,
      errWatchingInvoice: null == errWatchingInvoice
          ? _value.errWatchingInvoice
          : errWatchingInvoice // ignore: cast_nullable_to_non_nullable
              as String,
      boltzWatcher: freezed == boltzWatcher
          ? _value.boltzWatcher
          : boltzWatcher // ignore: cast_nullable_to_non_nullable
              as BoltzApi?,
      isTestnet: null == isTestnet
          ? _value.isTestnet
          : isTestnet // ignore: cast_nullable_to_non_nullable
              as bool,
      listeningTxs: null == listeningTxs
          ? _value._listeningTxs
          : listeningTxs // ignore: cast_nullable_to_non_nullable
              as List<String>,
      claimedSwapTxs: null == claimedSwapTxs
          ? _value._claimedSwapTxs
          : claimedSwapTxs // ignore: cast_nullable_to_non_nullable
              as List<String>,
      claimingSwapTxIds: null == claimingSwapTxIds
          ? _value._claimingSwapTxIds
          : claimingSwapTxIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      txPaid: freezed == txPaid
          ? _value.txPaid
          : txPaid // ignore: cast_nullable_to_non_nullable
              as Transaction?,
      syncWallet: freezed == syncWallet
          ? _value.syncWallet
          : syncWallet // ignore: cast_nullable_to_non_nullable
              as Wallet?,
    ));
  }
}

/// @nodoc

class _$WatchTxsStateImpl extends _WatchTxsState {
  const _$WatchTxsStateImpl(
      {this.errClaimingSwap = '',
      this.claimingSwap = false,
      this.errWatchingInvoice = '',
      this.boltzWatcher,
      required this.isTestnet,
      final List<String> listeningTxs = const [],
      final List<String> claimedSwapTxs = const [],
      final List<String> claimingSwapTxIds = const [],
      this.txPaid,
      this.syncWallet})
      : _listeningTxs = listeningTxs,
        _claimedSwapTxs = claimedSwapTxs,
        _claimingSwapTxIds = claimingSwapTxIds,
        super._();

  @override
  @JsonKey()
  final String errClaimingSwap;
  @override
  @JsonKey()
  final bool claimingSwap;
  @override
  @JsonKey()
  final String errWatchingInvoice;
  @override
  final BoltzApi? boltzWatcher;
  @override
  final bool isTestnet;
  final List<String> _listeningTxs;
  @override
  @JsonKey()
  List<String> get listeningTxs {
    if (_listeningTxs is EqualUnmodifiableListView) return _listeningTxs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_listeningTxs);
  }

  final List<String> _claimedSwapTxs;
  @override
  @JsonKey()
  List<String> get claimedSwapTxs {
    if (_claimedSwapTxs is EqualUnmodifiableListView) return _claimedSwapTxs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_claimedSwapTxs);
  }

  final List<String> _claimingSwapTxIds;
  @override
  @JsonKey()
  List<String> get claimingSwapTxIds {
    if (_claimingSwapTxIds is EqualUnmodifiableListView)
      return _claimingSwapTxIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_claimingSwapTxIds);
  }

  @override
  final Transaction? txPaid;
  @override
  final Wallet? syncWallet;

  @override
  String toString() {
    return 'WatchTxsState(errClaimingSwap: $errClaimingSwap, claimingSwap: $claimingSwap, errWatchingInvoice: $errWatchingInvoice, boltzWatcher: $boltzWatcher, isTestnet: $isTestnet, listeningTxs: $listeningTxs, claimedSwapTxs: $claimedSwapTxs, claimingSwapTxIds: $claimingSwapTxIds, txPaid: $txPaid, syncWallet: $syncWallet)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WatchTxsStateImpl &&
            (identical(other.errClaimingSwap, errClaimingSwap) ||
                other.errClaimingSwap == errClaimingSwap) &&
            (identical(other.claimingSwap, claimingSwap) ||
                other.claimingSwap == claimingSwap) &&
            (identical(other.errWatchingInvoice, errWatchingInvoice) ||
                other.errWatchingInvoice == errWatchingInvoice) &&
            (identical(other.boltzWatcher, boltzWatcher) ||
                other.boltzWatcher == boltzWatcher) &&
            (identical(other.isTestnet, isTestnet) ||
                other.isTestnet == isTestnet) &&
            const DeepCollectionEquality()
                .equals(other._listeningTxs, _listeningTxs) &&
            const DeepCollectionEquality()
                .equals(other._claimedSwapTxs, _claimedSwapTxs) &&
            const DeepCollectionEquality()
                .equals(other._claimingSwapTxIds, _claimingSwapTxIds) &&
            (identical(other.txPaid, txPaid) || other.txPaid == txPaid) &&
            (identical(other.syncWallet, syncWallet) ||
                other.syncWallet == syncWallet));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      errClaimingSwap,
      claimingSwap,
      errWatchingInvoice,
      boltzWatcher,
      isTestnet,
      const DeepCollectionEquality().hash(_listeningTxs),
      const DeepCollectionEquality().hash(_claimedSwapTxs),
      const DeepCollectionEquality().hash(_claimingSwapTxIds),
      txPaid,
      syncWallet);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$WatchTxsStateImplCopyWith<_$WatchTxsStateImpl> get copyWith =>
      __$$WatchTxsStateImplCopyWithImpl<_$WatchTxsStateImpl>(this, _$identity);
}

abstract class _WatchTxsState extends WatchTxsState {
  const factory _WatchTxsState(
      {final String errClaimingSwap,
      final bool claimingSwap,
      final String errWatchingInvoice,
      final BoltzApi? boltzWatcher,
      required final bool isTestnet,
      final List<String> listeningTxs,
      final List<String> claimedSwapTxs,
      final List<String> claimingSwapTxIds,
      final Transaction? txPaid,
      final Wallet? syncWallet}) = _$WatchTxsStateImpl;
  const _WatchTxsState._() : super._();

  @override
  String get errClaimingSwap;
  @override
  bool get claimingSwap;
  @override
  String get errWatchingInvoice;
  @override
  BoltzApi? get boltzWatcher;
  @override
  bool get isTestnet;
  @override
  List<String> get listeningTxs;
  @override
  List<String> get claimedSwapTxs;
  @override
  List<String> get claimingSwapTxIds;
  @override
  Transaction? get txPaid;
  @override
  Wallet? get syncWallet;
  @override
  @JsonKey(ignore: true)
  _$$WatchTxsStateImplCopyWith<_$WatchTxsStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

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
  String get errRefundingSwap => throw _privateConstructorUsedError;
  bool get claimingSwap => throw _privateConstructorUsedError;
  bool get refundingSwap => throw _privateConstructorUsedError;
  String get errWatchingInvoice => throw _privateConstructorUsedError;
  List<String> get listeningTxs => throw _privateConstructorUsedError;
  List<String> get claimedSwapTxs => throw _privateConstructorUsedError;
  List<String> get claimingSwapTxIds => throw _privateConstructorUsedError;
  List<String> get refundedSwapTxs => throw _privateConstructorUsedError;
  List<String> get refundingSwapTxIds => throw _privateConstructorUsedError;
  SwapTx? get updatedSwapTx => throw _privateConstructorUsedError;

  /// Create a copy of WatchTxsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
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
      String errRefundingSwap,
      bool claimingSwap,
      bool refundingSwap,
      String errWatchingInvoice,
      List<String> listeningTxs,
      List<String> claimedSwapTxs,
      List<String> claimingSwapTxIds,
      List<String> refundedSwapTxs,
      List<String> refundingSwapTxIds,
      SwapTx? updatedSwapTx});

  $SwapTxCopyWith<$Res>? get updatedSwapTx;
}

/// @nodoc
class _$WatchTxsStateCopyWithImpl<$Res, $Val extends WatchTxsState>
    implements $WatchTxsStateCopyWith<$Res> {
  _$WatchTxsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WatchTxsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? errClaimingSwap = null,
    Object? errRefundingSwap = null,
    Object? claimingSwap = null,
    Object? refundingSwap = null,
    Object? errWatchingInvoice = null,
    Object? listeningTxs = null,
    Object? claimedSwapTxs = null,
    Object? claimingSwapTxIds = null,
    Object? refundedSwapTxs = null,
    Object? refundingSwapTxIds = null,
    Object? updatedSwapTx = freezed,
  }) {
    return _then(_value.copyWith(
      errClaimingSwap: null == errClaimingSwap
          ? _value.errClaimingSwap
          : errClaimingSwap // ignore: cast_nullable_to_non_nullable
              as String,
      errRefundingSwap: null == errRefundingSwap
          ? _value.errRefundingSwap
          : errRefundingSwap // ignore: cast_nullable_to_non_nullable
              as String,
      claimingSwap: null == claimingSwap
          ? _value.claimingSwap
          : claimingSwap // ignore: cast_nullable_to_non_nullable
              as bool,
      refundingSwap: null == refundingSwap
          ? _value.refundingSwap
          : refundingSwap // ignore: cast_nullable_to_non_nullable
              as bool,
      errWatchingInvoice: null == errWatchingInvoice
          ? _value.errWatchingInvoice
          : errWatchingInvoice // ignore: cast_nullable_to_non_nullable
              as String,
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
      refundedSwapTxs: null == refundedSwapTxs
          ? _value.refundedSwapTxs
          : refundedSwapTxs // ignore: cast_nullable_to_non_nullable
              as List<String>,
      refundingSwapTxIds: null == refundingSwapTxIds
          ? _value.refundingSwapTxIds
          : refundingSwapTxIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      updatedSwapTx: freezed == updatedSwapTx
          ? _value.updatedSwapTx
          : updatedSwapTx // ignore: cast_nullable_to_non_nullable
              as SwapTx?,
    ) as $Val);
  }

  /// Create a copy of WatchTxsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SwapTxCopyWith<$Res>? get updatedSwapTx {
    if (_value.updatedSwapTx == null) {
      return null;
    }

    return $SwapTxCopyWith<$Res>(_value.updatedSwapTx!, (value) {
      return _then(_value.copyWith(updatedSwapTx: value) as $Val);
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
      String errRefundingSwap,
      bool claimingSwap,
      bool refundingSwap,
      String errWatchingInvoice,
      List<String> listeningTxs,
      List<String> claimedSwapTxs,
      List<String> claimingSwapTxIds,
      List<String> refundedSwapTxs,
      List<String> refundingSwapTxIds,
      SwapTx? updatedSwapTx});

  @override
  $SwapTxCopyWith<$Res>? get updatedSwapTx;
}

/// @nodoc
class __$$WatchTxsStateImplCopyWithImpl<$Res>
    extends _$WatchTxsStateCopyWithImpl<$Res, _$WatchTxsStateImpl>
    implements _$$WatchTxsStateImplCopyWith<$Res> {
  __$$WatchTxsStateImplCopyWithImpl(
      _$WatchTxsStateImpl _value, $Res Function(_$WatchTxsStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of WatchTxsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? errClaimingSwap = null,
    Object? errRefundingSwap = null,
    Object? claimingSwap = null,
    Object? refundingSwap = null,
    Object? errWatchingInvoice = null,
    Object? listeningTxs = null,
    Object? claimedSwapTxs = null,
    Object? claimingSwapTxIds = null,
    Object? refundedSwapTxs = null,
    Object? refundingSwapTxIds = null,
    Object? updatedSwapTx = freezed,
  }) {
    return _then(_$WatchTxsStateImpl(
      errClaimingSwap: null == errClaimingSwap
          ? _value.errClaimingSwap
          : errClaimingSwap // ignore: cast_nullable_to_non_nullable
              as String,
      errRefundingSwap: null == errRefundingSwap
          ? _value.errRefundingSwap
          : errRefundingSwap // ignore: cast_nullable_to_non_nullable
              as String,
      claimingSwap: null == claimingSwap
          ? _value.claimingSwap
          : claimingSwap // ignore: cast_nullable_to_non_nullable
              as bool,
      refundingSwap: null == refundingSwap
          ? _value.refundingSwap
          : refundingSwap // ignore: cast_nullable_to_non_nullable
              as bool,
      errWatchingInvoice: null == errWatchingInvoice
          ? _value.errWatchingInvoice
          : errWatchingInvoice // ignore: cast_nullable_to_non_nullable
              as String,
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
      refundedSwapTxs: null == refundedSwapTxs
          ? _value._refundedSwapTxs
          : refundedSwapTxs // ignore: cast_nullable_to_non_nullable
              as List<String>,
      refundingSwapTxIds: null == refundingSwapTxIds
          ? _value._refundingSwapTxIds
          : refundingSwapTxIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
      updatedSwapTx: freezed == updatedSwapTx
          ? _value.updatedSwapTx
          : updatedSwapTx // ignore: cast_nullable_to_non_nullable
              as SwapTx?,
    ));
  }
}

/// @nodoc

class _$WatchTxsStateImpl extends _WatchTxsState {
  const _$WatchTxsStateImpl(
      {this.errClaimingSwap = '',
      this.errRefundingSwap = '',
      this.claimingSwap = false,
      this.refundingSwap = false,
      this.errWatchingInvoice = '',
      final List<String> listeningTxs = const [],
      final List<String> claimedSwapTxs = const [],
      final List<String> claimingSwapTxIds = const [],
      final List<String> refundedSwapTxs = const [],
      final List<String> refundingSwapTxIds = const [],
      this.updatedSwapTx})
      : _listeningTxs = listeningTxs,
        _claimedSwapTxs = claimedSwapTxs,
        _claimingSwapTxIds = claimingSwapTxIds,
        _refundedSwapTxs = refundedSwapTxs,
        _refundingSwapTxIds = refundingSwapTxIds,
        super._();

  @override
  @JsonKey()
  final String errClaimingSwap;
  @override
  @JsonKey()
  final String errRefundingSwap;
  @override
  @JsonKey()
  final bool claimingSwap;
  @override
  @JsonKey()
  final bool refundingSwap;
  @override
  @JsonKey()
  final String errWatchingInvoice;
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

  final List<String> _refundedSwapTxs;
  @override
  @JsonKey()
  List<String> get refundedSwapTxs {
    if (_refundedSwapTxs is EqualUnmodifiableListView) return _refundedSwapTxs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_refundedSwapTxs);
  }

  final List<String> _refundingSwapTxIds;
  @override
  @JsonKey()
  List<String> get refundingSwapTxIds {
    if (_refundingSwapTxIds is EqualUnmodifiableListView)
      return _refundingSwapTxIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_refundingSwapTxIds);
  }

  @override
  final SwapTx? updatedSwapTx;

  @override
  String toString() {
    return 'WatchTxsState(errClaimingSwap: $errClaimingSwap, errRefundingSwap: $errRefundingSwap, claimingSwap: $claimingSwap, refundingSwap: $refundingSwap, errWatchingInvoice: $errWatchingInvoice, listeningTxs: $listeningTxs, claimedSwapTxs: $claimedSwapTxs, claimingSwapTxIds: $claimingSwapTxIds, refundedSwapTxs: $refundedSwapTxs, refundingSwapTxIds: $refundingSwapTxIds, updatedSwapTx: $updatedSwapTx)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WatchTxsStateImpl &&
            (identical(other.errClaimingSwap, errClaimingSwap) ||
                other.errClaimingSwap == errClaimingSwap) &&
            (identical(other.errRefundingSwap, errRefundingSwap) ||
                other.errRefundingSwap == errRefundingSwap) &&
            (identical(other.claimingSwap, claimingSwap) ||
                other.claimingSwap == claimingSwap) &&
            (identical(other.refundingSwap, refundingSwap) ||
                other.refundingSwap == refundingSwap) &&
            (identical(other.errWatchingInvoice, errWatchingInvoice) ||
                other.errWatchingInvoice == errWatchingInvoice) &&
            const DeepCollectionEquality()
                .equals(other._listeningTxs, _listeningTxs) &&
            const DeepCollectionEquality()
                .equals(other._claimedSwapTxs, _claimedSwapTxs) &&
            const DeepCollectionEquality()
                .equals(other._claimingSwapTxIds, _claimingSwapTxIds) &&
            const DeepCollectionEquality()
                .equals(other._refundedSwapTxs, _refundedSwapTxs) &&
            const DeepCollectionEquality()
                .equals(other._refundingSwapTxIds, _refundingSwapTxIds) &&
            (identical(other.updatedSwapTx, updatedSwapTx) ||
                other.updatedSwapTx == updatedSwapTx));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      errClaimingSwap,
      errRefundingSwap,
      claimingSwap,
      refundingSwap,
      errWatchingInvoice,
      const DeepCollectionEquality().hash(_listeningTxs),
      const DeepCollectionEquality().hash(_claimedSwapTxs),
      const DeepCollectionEquality().hash(_claimingSwapTxIds),
      const DeepCollectionEquality().hash(_refundedSwapTxs),
      const DeepCollectionEquality().hash(_refundingSwapTxIds),
      updatedSwapTx);

  /// Create a copy of WatchTxsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WatchTxsStateImplCopyWith<_$WatchTxsStateImpl> get copyWith =>
      __$$WatchTxsStateImplCopyWithImpl<_$WatchTxsStateImpl>(this, _$identity);
}

abstract class _WatchTxsState extends WatchTxsState {
  const factory _WatchTxsState(
      {final String errClaimingSwap,
      final String errRefundingSwap,
      final bool claimingSwap,
      final bool refundingSwap,
      final String errWatchingInvoice,
      final List<String> listeningTxs,
      final List<String> claimedSwapTxs,
      final List<String> claimingSwapTxIds,
      final List<String> refundedSwapTxs,
      final List<String> refundingSwapTxIds,
      final SwapTx? updatedSwapTx}) = _$WatchTxsStateImpl;
  const _WatchTxsState._() : super._();

  @override
  String get errClaimingSwap;
  @override
  String get errRefundingSwap;
  @override
  bool get claimingSwap;
  @override
  bool get refundingSwap;
  @override
  String get errWatchingInvoice;
  @override
  List<String> get listeningTxs;
  @override
  List<String> get claimedSwapTxs;
  @override
  List<String> get claimingSwapTxIds;
  @override
  List<String> get refundedSwapTxs;
  @override
  List<String> get refundingSwapTxIds;
  @override
  SwapTx? get updatedSwapTx;

  /// Create a copy of WatchTxsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WatchTxsStateImplCopyWith<_$WatchTxsStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

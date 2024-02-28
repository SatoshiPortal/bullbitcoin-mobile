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
  String get errClaimingSwap => throw _privateConstructorUsedError;
  bool get claimingSwapSwap => throw _privateConstructorUsedError;
  String get errWatchingInvoice => throw _privateConstructorUsedError;
  SwapTx? get swapTx => throw _privateConstructorUsedError;
  BoltzApi? get boltzWatcher => throw _privateConstructorUsedError;
  List<SwapTx> get listeningTxs => throw _privateConstructorUsedError;
  List<SwapTx> get claimedSwapTxs => throw _privateConstructorUsedError;

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
      String errClaimingSwap,
      bool claimingSwapSwap,
      String errWatchingInvoice,
      SwapTx? swapTx,
      BoltzApi? boltzWatcher,
      List<SwapTx> listeningTxs,
      List<SwapTx> claimedSwapTxs});

  $SwapTxCopyWith<$Res>? get swapTx;
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
    Object? errClaimingSwap = null,
    Object? claimingSwapSwap = null,
    Object? errWatchingInvoice = null,
    Object? swapTx = freezed,
    Object? boltzWatcher = freezed,
    Object? listeningTxs = null,
    Object? claimedSwapTxs = null,
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
      errClaimingSwap: null == errClaimingSwap
          ? _value.errClaimingSwap
          : errClaimingSwap // ignore: cast_nullable_to_non_nullable
              as String,
      claimingSwapSwap: null == claimingSwapSwap
          ? _value.claimingSwapSwap
          : claimingSwapSwap // ignore: cast_nullable_to_non_nullable
              as bool,
      errWatchingInvoice: null == errWatchingInvoice
          ? _value.errWatchingInvoice
          : errWatchingInvoice // ignore: cast_nullable_to_non_nullable
              as String,
      swapTx: freezed == swapTx
          ? _value.swapTx
          : swapTx // ignore: cast_nullable_to_non_nullable
              as SwapTx?,
      boltzWatcher: freezed == boltzWatcher
          ? _value.boltzWatcher
          : boltzWatcher // ignore: cast_nullable_to_non_nullable
              as BoltzApi?,
      listeningTxs: null == listeningTxs
          ? _value.listeningTxs
          : listeningTxs // ignore: cast_nullable_to_non_nullable
              as List<SwapTx>,
      claimedSwapTxs: null == claimedSwapTxs
          ? _value.claimedSwapTxs
          : claimedSwapTxs // ignore: cast_nullable_to_non_nullable
              as List<SwapTx>,
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
      String errClaimingSwap,
      bool claimingSwapSwap,
      String errWatchingInvoice,
      SwapTx? swapTx,
      BoltzApi? boltzWatcher,
      List<SwapTx> listeningTxs,
      List<SwapTx> claimedSwapTxs});

  @override
  $SwapTxCopyWith<$Res>? get swapTx;
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
    Object? errClaimingSwap = null,
    Object? claimingSwapSwap = null,
    Object? errWatchingInvoice = null,
    Object? swapTx = freezed,
    Object? boltzWatcher = freezed,
    Object? listeningTxs = null,
    Object? claimedSwapTxs = null,
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
      errClaimingSwap: null == errClaimingSwap
          ? _value.errClaimingSwap
          : errClaimingSwap // ignore: cast_nullable_to_non_nullable
              as String,
      claimingSwapSwap: null == claimingSwapSwap
          ? _value.claimingSwapSwap
          : claimingSwapSwap // ignore: cast_nullable_to_non_nullable
              as bool,
      errWatchingInvoice: null == errWatchingInvoice
          ? _value.errWatchingInvoice
          : errWatchingInvoice // ignore: cast_nullable_to_non_nullable
              as String,
      swapTx: freezed == swapTx
          ? _value.swapTx
          : swapTx // ignore: cast_nullable_to_non_nullable
              as SwapTx?,
      boltzWatcher: freezed == boltzWatcher
          ? _value.boltzWatcher
          : boltzWatcher // ignore: cast_nullable_to_non_nullable
              as BoltzApi?,
      listeningTxs: null == listeningTxs
          ? _value._listeningTxs
          : listeningTxs // ignore: cast_nullable_to_non_nullable
              as List<SwapTx>,
      claimedSwapTxs: null == claimedSwapTxs
          ? _value._claimedSwapTxs
          : claimedSwapTxs // ignore: cast_nullable_to_non_nullable
              as List<SwapTx>,
    ));
  }
}

/// @nodoc

class _$SwapStateImpl extends _SwapState {
  const _$SwapStateImpl(
      {this.creatingInvoice = true,
      this.errCreatingInvoice = '',
      this.errCreatingSwapInv = '',
      this.generatingSwapInv = false,
      this.errClaimingSwap = '',
      this.claimingSwapSwap = false,
      this.errWatchingInvoice = '',
      this.swapTx,
      this.boltzWatcher,
      final List<SwapTx> listeningTxs = const [],
      final List<SwapTx> claimedSwapTxs = const []})
      : _listeningTxs = listeningTxs,
        _claimedSwapTxs = claimedSwapTxs,
        super._();

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
  @JsonKey()
  final String errClaimingSwap;
  @override
  @JsonKey()
  final bool claimingSwapSwap;
  @override
  @JsonKey()
  final String errWatchingInvoice;
  @override
  final SwapTx? swapTx;
  @override
  final BoltzApi? boltzWatcher;
  final List<SwapTx> _listeningTxs;
  @override
  @JsonKey()
  List<SwapTx> get listeningTxs {
    if (_listeningTxs is EqualUnmodifiableListView) return _listeningTxs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_listeningTxs);
  }

  final List<SwapTx> _claimedSwapTxs;
  @override
  @JsonKey()
  List<SwapTx> get claimedSwapTxs {
    if (_claimedSwapTxs is EqualUnmodifiableListView) return _claimedSwapTxs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_claimedSwapTxs);
  }

  @override
  String toString() {
    return 'SwapState(creatingInvoice: $creatingInvoice, errCreatingInvoice: $errCreatingInvoice, errCreatingSwapInv: $errCreatingSwapInv, generatingSwapInv: $generatingSwapInv, errClaimingSwap: $errClaimingSwap, claimingSwapSwap: $claimingSwapSwap, errWatchingInvoice: $errWatchingInvoice, swapTx: $swapTx, boltzWatcher: $boltzWatcher, listeningTxs: $listeningTxs, claimedSwapTxs: $claimedSwapTxs)';
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
            (identical(other.errClaimingSwap, errClaimingSwap) ||
                other.errClaimingSwap == errClaimingSwap) &&
            (identical(other.claimingSwapSwap, claimingSwapSwap) ||
                other.claimingSwapSwap == claimingSwapSwap) &&
            (identical(other.errWatchingInvoice, errWatchingInvoice) ||
                other.errWatchingInvoice == errWatchingInvoice) &&
            (identical(other.swapTx, swapTx) || other.swapTx == swapTx) &&
            (identical(other.boltzWatcher, boltzWatcher) ||
                other.boltzWatcher == boltzWatcher) &&
            const DeepCollectionEquality()
                .equals(other._listeningTxs, _listeningTxs) &&
            const DeepCollectionEquality()
                .equals(other._claimedSwapTxs, _claimedSwapTxs));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      creatingInvoice,
      errCreatingInvoice,
      errCreatingSwapInv,
      generatingSwapInv,
      errClaimingSwap,
      claimingSwapSwap,
      errWatchingInvoice,
      swapTx,
      boltzWatcher,
      const DeepCollectionEquality().hash(_listeningTxs),
      const DeepCollectionEquality().hash(_claimedSwapTxs));

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
      final String errClaimingSwap,
      final bool claimingSwapSwap,
      final String errWatchingInvoice,
      final SwapTx? swapTx,
      final BoltzApi? boltzWatcher,
      final List<SwapTx> listeningTxs,
      final List<SwapTx> claimedSwapTxs}) = _$SwapStateImpl;
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
  String get errClaimingSwap;
  @override
  bool get claimingSwapSwap;
  @override
  String get errWatchingInvoice;
  @override
  SwapTx? get swapTx;
  @override
  BoltzApi? get boltzWatcher;
  @override
  List<SwapTx> get listeningTxs;
  @override
  List<SwapTx> get claimedSwapTxs;
  @override
  @JsonKey(ignore: true)
  _$$SwapStateImplCopyWith<_$SwapStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

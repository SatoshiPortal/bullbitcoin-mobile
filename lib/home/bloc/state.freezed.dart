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
mixin _$HomeState {
  List<Wallet>? get wallets => throw _privateConstructorUsedError;
  List<WalletBloc>? get walletBlocs => throw _privateConstructorUsedError;
  bool get loadingWallets => throw _privateConstructorUsedError;
  String get errLoadingWallets =>
      throw _privateConstructorUsedError; // Wallet? selectedWallet,
  WalletBloc? get selectedWalletCubit => throw _privateConstructorUsedError;
  int? get lastTestnetWalletIdx => throw _privateConstructorUsedError;
  int? get lastMainnetWalletIdx => throw _privateConstructorUsedError;
  String get errDeepLinking => throw _privateConstructorUsedError;
  int? get moveToIdx => throw _privateConstructorUsedError;

  /// Create a copy of HomeState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HomeStateCopyWith<HomeState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HomeStateCopyWith<$Res> {
  factory $HomeStateCopyWith(HomeState value, $Res Function(HomeState) then) =
      _$HomeStateCopyWithImpl<$Res, HomeState>;
  @useResult
  $Res call(
      {List<Wallet>? wallets,
      List<WalletBloc>? walletBlocs,
      bool loadingWallets,
      String errLoadingWallets,
      WalletBloc? selectedWalletCubit,
      int? lastTestnetWalletIdx,
      int? lastMainnetWalletIdx,
      String errDeepLinking,
      int? moveToIdx});
}

/// @nodoc
class _$HomeStateCopyWithImpl<$Res, $Val extends HomeState>
    implements $HomeStateCopyWith<$Res> {
  _$HomeStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HomeState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? wallets = freezed,
    Object? walletBlocs = freezed,
    Object? loadingWallets = null,
    Object? errLoadingWallets = null,
    Object? selectedWalletCubit = freezed,
    Object? lastTestnetWalletIdx = freezed,
    Object? lastMainnetWalletIdx = freezed,
    Object? errDeepLinking = null,
    Object? moveToIdx = freezed,
  }) {
    return _then(_value.copyWith(
      wallets: freezed == wallets
          ? _value.wallets
          : wallets // ignore: cast_nullable_to_non_nullable
              as List<Wallet>?,
      walletBlocs: freezed == walletBlocs
          ? _value.walletBlocs
          : walletBlocs // ignore: cast_nullable_to_non_nullable
              as List<WalletBloc>?,
      loadingWallets: null == loadingWallets
          ? _value.loadingWallets
          : loadingWallets // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingWallets: null == errLoadingWallets
          ? _value.errLoadingWallets
          : errLoadingWallets // ignore: cast_nullable_to_non_nullable
              as String,
      selectedWalletCubit: freezed == selectedWalletCubit
          ? _value.selectedWalletCubit
          : selectedWalletCubit // ignore: cast_nullable_to_non_nullable
              as WalletBloc?,
      lastTestnetWalletIdx: freezed == lastTestnetWalletIdx
          ? _value.lastTestnetWalletIdx
          : lastTestnetWalletIdx // ignore: cast_nullable_to_non_nullable
              as int?,
      lastMainnetWalletIdx: freezed == lastMainnetWalletIdx
          ? _value.lastMainnetWalletIdx
          : lastMainnetWalletIdx // ignore: cast_nullable_to_non_nullable
              as int?,
      errDeepLinking: null == errDeepLinking
          ? _value.errDeepLinking
          : errDeepLinking // ignore: cast_nullable_to_non_nullable
              as String,
      moveToIdx: freezed == moveToIdx
          ? _value.moveToIdx
          : moveToIdx // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$HomeStateImplCopyWith<$Res>
    implements $HomeStateCopyWith<$Res> {
  factory _$$HomeStateImplCopyWith(
          _$HomeStateImpl value, $Res Function(_$HomeStateImpl) then) =
      __$$HomeStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<Wallet>? wallets,
      List<WalletBloc>? walletBlocs,
      bool loadingWallets,
      String errLoadingWallets,
      WalletBloc? selectedWalletCubit,
      int? lastTestnetWalletIdx,
      int? lastMainnetWalletIdx,
      String errDeepLinking,
      int? moveToIdx});
}

/// @nodoc
class __$$HomeStateImplCopyWithImpl<$Res>
    extends _$HomeStateCopyWithImpl<$Res, _$HomeStateImpl>
    implements _$$HomeStateImplCopyWith<$Res> {
  __$$HomeStateImplCopyWithImpl(
      _$HomeStateImpl _value, $Res Function(_$HomeStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of HomeState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? wallets = freezed,
    Object? walletBlocs = freezed,
    Object? loadingWallets = null,
    Object? errLoadingWallets = null,
    Object? selectedWalletCubit = freezed,
    Object? lastTestnetWalletIdx = freezed,
    Object? lastMainnetWalletIdx = freezed,
    Object? errDeepLinking = null,
    Object? moveToIdx = freezed,
  }) {
    return _then(_$HomeStateImpl(
      wallets: freezed == wallets
          ? _value._wallets
          : wallets // ignore: cast_nullable_to_non_nullable
              as List<Wallet>?,
      walletBlocs: freezed == walletBlocs
          ? _value._walletBlocs
          : walletBlocs // ignore: cast_nullable_to_non_nullable
              as List<WalletBloc>?,
      loadingWallets: null == loadingWallets
          ? _value.loadingWallets
          : loadingWallets // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingWallets: null == errLoadingWallets
          ? _value.errLoadingWallets
          : errLoadingWallets // ignore: cast_nullable_to_non_nullable
              as String,
      selectedWalletCubit: freezed == selectedWalletCubit
          ? _value.selectedWalletCubit
          : selectedWalletCubit // ignore: cast_nullable_to_non_nullable
              as WalletBloc?,
      lastTestnetWalletIdx: freezed == lastTestnetWalletIdx
          ? _value.lastTestnetWalletIdx
          : lastTestnetWalletIdx // ignore: cast_nullable_to_non_nullable
              as int?,
      lastMainnetWalletIdx: freezed == lastMainnetWalletIdx
          ? _value.lastMainnetWalletIdx
          : lastMainnetWalletIdx // ignore: cast_nullable_to_non_nullable
              as int?,
      errDeepLinking: null == errDeepLinking
          ? _value.errDeepLinking
          : errDeepLinking // ignore: cast_nullable_to_non_nullable
              as String,
      moveToIdx: freezed == moveToIdx
          ? _value.moveToIdx
          : moveToIdx // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc

class _$HomeStateImpl extends _HomeState {
  const _$HomeStateImpl(
      {final List<Wallet>? wallets,
      final List<WalletBloc>? walletBlocs,
      this.loadingWallets = true,
      this.errLoadingWallets = '',
      this.selectedWalletCubit,
      this.lastTestnetWalletIdx,
      this.lastMainnetWalletIdx,
      this.errDeepLinking = '',
      this.moveToIdx})
      : _wallets = wallets,
        _walletBlocs = walletBlocs,
        super._();

  final List<Wallet>? _wallets;
  @override
  List<Wallet>? get wallets {
    final value = _wallets;
    if (value == null) return null;
    if (_wallets is EqualUnmodifiableListView) return _wallets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<WalletBloc>? _walletBlocs;
  @override
  List<WalletBloc>? get walletBlocs {
    final value = _walletBlocs;
    if (value == null) return null;
    if (_walletBlocs is EqualUnmodifiableListView) return _walletBlocs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey()
  final bool loadingWallets;
  @override
  @JsonKey()
  final String errLoadingWallets;
// Wallet? selectedWallet,
  @override
  final WalletBloc? selectedWalletCubit;
  @override
  final int? lastTestnetWalletIdx;
  @override
  final int? lastMainnetWalletIdx;
  @override
  @JsonKey()
  final String errDeepLinking;
  @override
  final int? moveToIdx;

  @override
  String toString() {
    return 'HomeState(wallets: $wallets, walletBlocs: $walletBlocs, loadingWallets: $loadingWallets, errLoadingWallets: $errLoadingWallets, selectedWalletCubit: $selectedWalletCubit, lastTestnetWalletIdx: $lastTestnetWalletIdx, lastMainnetWalletIdx: $lastMainnetWalletIdx, errDeepLinking: $errDeepLinking, moveToIdx: $moveToIdx)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HomeStateImpl &&
            const DeepCollectionEquality().equals(other._wallets, _wallets) &&
            const DeepCollectionEquality()
                .equals(other._walletBlocs, _walletBlocs) &&
            (identical(other.loadingWallets, loadingWallets) ||
                other.loadingWallets == loadingWallets) &&
            (identical(other.errLoadingWallets, errLoadingWallets) ||
                other.errLoadingWallets == errLoadingWallets) &&
            (identical(other.selectedWalletCubit, selectedWalletCubit) ||
                other.selectedWalletCubit == selectedWalletCubit) &&
            (identical(other.lastTestnetWalletIdx, lastTestnetWalletIdx) ||
                other.lastTestnetWalletIdx == lastTestnetWalletIdx) &&
            (identical(other.lastMainnetWalletIdx, lastMainnetWalletIdx) ||
                other.lastMainnetWalletIdx == lastMainnetWalletIdx) &&
            (identical(other.errDeepLinking, errDeepLinking) ||
                other.errDeepLinking == errDeepLinking) &&
            (identical(other.moveToIdx, moveToIdx) ||
                other.moveToIdx == moveToIdx));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_wallets),
      const DeepCollectionEquality().hash(_walletBlocs),
      loadingWallets,
      errLoadingWallets,
      selectedWalletCubit,
      lastTestnetWalletIdx,
      lastMainnetWalletIdx,
      errDeepLinking,
      moveToIdx);

  /// Create a copy of HomeState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HomeStateImplCopyWith<_$HomeStateImpl> get copyWith =>
      __$$HomeStateImplCopyWithImpl<_$HomeStateImpl>(this, _$identity);
}

abstract class _HomeState extends HomeState {
  const factory _HomeState(
      {final List<Wallet>? wallets,
      final List<WalletBloc>? walletBlocs,
      final bool loadingWallets,
      final String errLoadingWallets,
      final WalletBloc? selectedWalletCubit,
      final int? lastTestnetWalletIdx,
      final int? lastMainnetWalletIdx,
      final String errDeepLinking,
      final int? moveToIdx}) = _$HomeStateImpl;
  const _HomeState._() : super._();

  @override
  List<Wallet>? get wallets;
  @override
  List<WalletBloc>? get walletBlocs;
  @override
  bool get loadingWallets;
  @override
  String get errLoadingWallets; // Wallet? selectedWallet,
  @override
  WalletBloc? get selectedWalletCubit;
  @override
  int? get lastTestnetWalletIdx;
  @override
  int? get lastMainnetWalletIdx;
  @override
  String get errDeepLinking;
  @override
  int? get moveToIdx;

  /// Create a copy of HomeState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HomeStateImplCopyWith<_$HomeStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

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
mixin _$HomeState {
  List<Wallet>? get wallets => throw _privateConstructorUsedError;
  List<WalletBloc>? get walletBlocs => throw _privateConstructorUsedError;
  bool get loadingWallets => throw _privateConstructorUsedError;
  String get errLoadingWallets =>
      throw _privateConstructorUsedError; // Wallet? selectedWallet,
  WalletBloc? get selectedWalletCubit => throw _privateConstructorUsedError;
  String get errDeepLinking => throw _privateConstructorUsedError;
  int? get moveToIdx => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
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

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? wallets = freezed,
    Object? walletBlocs = freezed,
    Object? loadingWallets = null,
    Object? errLoadingWallets = null,
    Object? selectedWalletCubit = freezed,
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
abstract class _$$_HomeStateCopyWith<$Res> implements $HomeStateCopyWith<$Res> {
  factory _$$_HomeStateCopyWith(
          _$_HomeState value, $Res Function(_$_HomeState) then) =
      __$$_HomeStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<Wallet>? wallets,
      List<WalletBloc>? walletBlocs,
      bool loadingWallets,
      String errLoadingWallets,
      WalletBloc? selectedWalletCubit,
      String errDeepLinking,
      int? moveToIdx});
}

/// @nodoc
class __$$_HomeStateCopyWithImpl<$Res>
    extends _$HomeStateCopyWithImpl<$Res, _$_HomeState>
    implements _$$_HomeStateCopyWith<$Res> {
  __$$_HomeStateCopyWithImpl(
      _$_HomeState _value, $Res Function(_$_HomeState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? wallets = freezed,
    Object? walletBlocs = freezed,
    Object? loadingWallets = null,
    Object? errLoadingWallets = null,
    Object? selectedWalletCubit = freezed,
    Object? errDeepLinking = null,
    Object? moveToIdx = freezed,
  }) {
    return _then(_$_HomeState(
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

class _$_HomeState extends _HomeState {
  const _$_HomeState(
      {final List<Wallet>? wallets,
      final List<WalletBloc>? walletBlocs,
      this.loadingWallets = true,
      this.errLoadingWallets = '',
      this.selectedWalletCubit,
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
  @JsonKey()
  final String errDeepLinking;
  @override
  final int? moveToIdx;

  @override
  String toString() {
    return 'HomeState(wallets: $wallets, walletBlocs: $walletBlocs, loadingWallets: $loadingWallets, errLoadingWallets: $errLoadingWallets, selectedWalletCubit: $selectedWalletCubit, errDeepLinking: $errDeepLinking, moveToIdx: $moveToIdx)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_HomeState &&
            const DeepCollectionEquality().equals(other._wallets, _wallets) &&
            const DeepCollectionEquality()
                .equals(other._walletBlocs, _walletBlocs) &&
            (identical(other.loadingWallets, loadingWallets) ||
                other.loadingWallets == loadingWallets) &&
            (identical(other.errLoadingWallets, errLoadingWallets) ||
                other.errLoadingWallets == errLoadingWallets) &&
            (identical(other.selectedWalletCubit, selectedWalletCubit) ||
                other.selectedWalletCubit == selectedWalletCubit) &&
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
      errDeepLinking,
      moveToIdx);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_HomeStateCopyWith<_$_HomeState> get copyWith =>
      __$$_HomeStateCopyWithImpl<_$_HomeState>(this, _$identity);
}

abstract class _HomeState extends HomeState {
  const factory _HomeState(
      {final List<Wallet>? wallets,
      final List<WalletBloc>? walletBlocs,
      final bool loadingWallets,
      final String errLoadingWallets,
      final WalletBloc? selectedWalletCubit,
      final String errDeepLinking,
      final int? moveToIdx}) = _$_HomeState;
  const _HomeState._() : super._();

  @override
  List<Wallet>? get wallets;
  @override
  List<WalletBloc>? get walletBlocs;
  @override
  bool get loadingWallets;
  @override
  String get errLoadingWallets;
  @override // Wallet? selectedWallet,
  WalletBloc? get selectedWalletCubit;
  @override
  String get errDeepLinking;
  @override
  int? get moveToIdx;
  @override
  @JsonKey(ignore: true)
  _$$_HomeStateCopyWith<_$_HomeState> get copyWith =>
      throw _privateConstructorUsedError;
}

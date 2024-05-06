// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'home_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$HomeState {
  List<Wallet>? get tempwallets => throw _privateConstructorUsedError;
  List<WalletBloc>? get walletBlocs => throw _privateConstructorUsedError;
  bool get loadingWallets => throw _privateConstructorUsedError;
  String get errLoadingWallets =>
      throw _privateConstructorUsedError; // Wallet? selectedWallet,
// WalletBloc? selectedWalletCubit,
// int? lastTestnetWalletIdx,
// int? lastMainnetWalletIdx,
  String get errDeepLinking => throw _privateConstructorUsedError;
  bool get updated => throw _privateConstructorUsedError;
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
      {List<Wallet>? tempwallets,
      List<WalletBloc>? walletBlocs,
      bool loadingWallets,
      String errLoadingWallets,
      String errDeepLinking,
      bool updated,
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
    Object? tempwallets = freezed,
    Object? walletBlocs = freezed,
    Object? loadingWallets = null,
    Object? errLoadingWallets = null,
    Object? errDeepLinking = null,
    Object? updated = null,
    Object? moveToIdx = freezed,
  }) {
    return _then(_value.copyWith(
      tempwallets: freezed == tempwallets
          ? _value.tempwallets
          : tempwallets // ignore: cast_nullable_to_non_nullable
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
      errDeepLinking: null == errDeepLinking
          ? _value.errDeepLinking
          : errDeepLinking // ignore: cast_nullable_to_non_nullable
              as String,
      updated: null == updated
          ? _value.updated
          : updated // ignore: cast_nullable_to_non_nullable
              as bool,
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
      {List<Wallet>? tempwallets,
      List<WalletBloc>? walletBlocs,
      bool loadingWallets,
      String errLoadingWallets,
      String errDeepLinking,
      bool updated,
      int? moveToIdx});
}

/// @nodoc
class __$$HomeStateImplCopyWithImpl<$Res>
    extends _$HomeStateCopyWithImpl<$Res, _$HomeStateImpl>
    implements _$$HomeStateImplCopyWith<$Res> {
  __$$HomeStateImplCopyWithImpl(
      _$HomeStateImpl _value, $Res Function(_$HomeStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tempwallets = freezed,
    Object? walletBlocs = freezed,
    Object? loadingWallets = null,
    Object? errLoadingWallets = null,
    Object? errDeepLinking = null,
    Object? updated = null,
    Object? moveToIdx = freezed,
  }) {
    return _then(_$HomeStateImpl(
      tempwallets: freezed == tempwallets
          ? _value._tempwallets
          : tempwallets // ignore: cast_nullable_to_non_nullable
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
      errDeepLinking: null == errDeepLinking
          ? _value.errDeepLinking
          : errDeepLinking // ignore: cast_nullable_to_non_nullable
              as String,
      updated: null == updated
          ? _value.updated
          : updated // ignore: cast_nullable_to_non_nullable
              as bool,
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
      {final List<Wallet>? tempwallets,
      final List<WalletBloc>? walletBlocs,
      this.loadingWallets = true,
      this.errLoadingWallets = '',
      this.errDeepLinking = '',
      this.updated = false,
      this.moveToIdx})
      : _tempwallets = tempwallets,
        _walletBlocs = walletBlocs,
        super._();

  final List<Wallet>? _tempwallets;
  @override
  List<Wallet>? get tempwallets {
    final value = _tempwallets;
    if (value == null) return null;
    if (_tempwallets is EqualUnmodifiableListView) return _tempwallets;
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
// WalletBloc? selectedWalletCubit,
// int? lastTestnetWalletIdx,
// int? lastMainnetWalletIdx,
  @override
  @JsonKey()
  final String errDeepLinking;
  @override
  @JsonKey()
  final bool updated;
  @override
  final int? moveToIdx;

  @override
  String toString() {
    return 'HomeState(tempwallets: $tempwallets, walletBlocs: $walletBlocs, loadingWallets: $loadingWallets, errLoadingWallets: $errLoadingWallets, errDeepLinking: $errDeepLinking, updated: $updated, moveToIdx: $moveToIdx)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HomeStateImpl &&
            const DeepCollectionEquality()
                .equals(other._tempwallets, _tempwallets) &&
            const DeepCollectionEquality()
                .equals(other._walletBlocs, _walletBlocs) &&
            (identical(other.loadingWallets, loadingWallets) ||
                other.loadingWallets == loadingWallets) &&
            (identical(other.errLoadingWallets, errLoadingWallets) ||
                other.errLoadingWallets == errLoadingWallets) &&
            (identical(other.errDeepLinking, errDeepLinking) ||
                other.errDeepLinking == errDeepLinking) &&
            (identical(other.updated, updated) || other.updated == updated) &&
            (identical(other.moveToIdx, moveToIdx) ||
                other.moveToIdx == moveToIdx));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_tempwallets),
      const DeepCollectionEquality().hash(_walletBlocs),
      loadingWallets,
      errLoadingWallets,
      errDeepLinking,
      updated,
      moveToIdx);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$HomeStateImplCopyWith<_$HomeStateImpl> get copyWith =>
      __$$HomeStateImplCopyWithImpl<_$HomeStateImpl>(this, _$identity);
}

abstract class _HomeState extends HomeState {
  const factory _HomeState(
      {final List<Wallet>? tempwallets,
      final List<WalletBloc>? walletBlocs,
      final bool loadingWallets,
      final String errLoadingWallets,
      final String errDeepLinking,
      final bool updated,
      final int? moveToIdx}) = _$HomeStateImpl;
  const _HomeState._() : super._();

  @override
  List<Wallet>? get tempwallets;
  @override
  List<WalletBloc>? get walletBlocs;
  @override
  bool get loadingWallets;
  @override
  String get errLoadingWallets;
  @override // Wallet? selectedWallet,
// WalletBloc? selectedWalletCubit,
// int? lastTestnetWalletIdx,
// int? lastMainnetWalletIdx,
  String get errDeepLinking;
  @override
  bool get updated;
  @override
  int? get moveToIdx;
  @override
  @JsonKey(ignore: true)
  _$$HomeStateImplCopyWith<_$HomeStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

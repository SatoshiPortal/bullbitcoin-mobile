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
mixin _$CreateWalletState {
/**
     * 
     * SENSITIVE
     * 
     */
  List<String>? get mnemonic => throw _privateConstructorUsedError;
  String get passPhrase => throw _privateConstructorUsedError;
  /**
     * 
     * SENSITIVE
     * 
     */
  bool get creatingNmemonic => throw _privateConstructorUsedError;
  String get errCreatingNmemonic => throw _privateConstructorUsedError;
  bool get saving => throw _privateConstructorUsedError;
  String get errSaving => throw _privateConstructorUsedError;
  bool get saved => throw _privateConstructorUsedError;
  String? get walletLabel => throw _privateConstructorUsedError;
  Wallet? get savedWallet => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $CreateWalletStateCopyWith<CreateWalletState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CreateWalletStateCopyWith<$Res> {
  factory $CreateWalletStateCopyWith(
          CreateWalletState value, $Res Function(CreateWalletState) then) =
      _$CreateWalletStateCopyWithImpl<$Res, CreateWalletState>;
  @useResult
  $Res call(
      {List<String>? mnemonic,
      String passPhrase,
      bool creatingNmemonic,
      String errCreatingNmemonic,
      bool saving,
      String errSaving,
      bool saved,
      String? walletLabel,
      Wallet? savedWallet});

  $WalletCopyWith<$Res>? get savedWallet;
}

/// @nodoc
class _$CreateWalletStateCopyWithImpl<$Res, $Val extends CreateWalletState>
    implements $CreateWalletStateCopyWith<$Res> {
  _$CreateWalletStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mnemonic = freezed,
    Object? passPhrase = null,
    Object? creatingNmemonic = null,
    Object? errCreatingNmemonic = null,
    Object? saving = null,
    Object? errSaving = null,
    Object? saved = null,
    Object? walletLabel = freezed,
    Object? savedWallet = freezed,
  }) {
    return _then(_value.copyWith(
      mnemonic: freezed == mnemonic
          ? _value.mnemonic
          : mnemonic // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      passPhrase: null == passPhrase
          ? _value.passPhrase
          : passPhrase // ignore: cast_nullable_to_non_nullable
              as String,
      creatingNmemonic: null == creatingNmemonic
          ? _value.creatingNmemonic
          : creatingNmemonic // ignore: cast_nullable_to_non_nullable
              as bool,
      errCreatingNmemonic: null == errCreatingNmemonic
          ? _value.errCreatingNmemonic
          : errCreatingNmemonic // ignore: cast_nullable_to_non_nullable
              as String,
      saving: null == saving
          ? _value.saving
          : saving // ignore: cast_nullable_to_non_nullable
              as bool,
      errSaving: null == errSaving
          ? _value.errSaving
          : errSaving // ignore: cast_nullable_to_non_nullable
              as String,
      saved: null == saved
          ? _value.saved
          : saved // ignore: cast_nullable_to_non_nullable
              as bool,
      walletLabel: freezed == walletLabel
          ? _value.walletLabel
          : walletLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      savedWallet: freezed == savedWallet
          ? _value.savedWallet
          : savedWallet // ignore: cast_nullable_to_non_nullable
              as Wallet?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $WalletCopyWith<$Res>? get savedWallet {
    if (_value.savedWallet == null) {
      return null;
    }

    return $WalletCopyWith<$Res>(_value.savedWallet!, (value) {
      return _then(_value.copyWith(savedWallet: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$CreateWalletStateImplCopyWith<$Res>
    implements $CreateWalletStateCopyWith<$Res> {
  factory _$$CreateWalletStateImplCopyWith(_$CreateWalletStateImpl value,
          $Res Function(_$CreateWalletStateImpl) then) =
      __$$CreateWalletStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<String>? mnemonic,
      String passPhrase,
      bool creatingNmemonic,
      String errCreatingNmemonic,
      bool saving,
      String errSaving,
      bool saved,
      String? walletLabel,
      Wallet? savedWallet});

  @override
  $WalletCopyWith<$Res>? get savedWallet;
}

/// @nodoc
class __$$CreateWalletStateImplCopyWithImpl<$Res>
    extends _$CreateWalletStateCopyWithImpl<$Res, _$CreateWalletStateImpl>
    implements _$$CreateWalletStateImplCopyWith<$Res> {
  __$$CreateWalletStateImplCopyWithImpl(_$CreateWalletStateImpl _value,
      $Res Function(_$CreateWalletStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mnemonic = freezed,
    Object? passPhrase = null,
    Object? creatingNmemonic = null,
    Object? errCreatingNmemonic = null,
    Object? saving = null,
    Object? errSaving = null,
    Object? saved = null,
    Object? walletLabel = freezed,
    Object? savedWallet = freezed,
  }) {
    return _then(_$CreateWalletStateImpl(
      mnemonic: freezed == mnemonic
          ? _value._mnemonic
          : mnemonic // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      passPhrase: null == passPhrase
          ? _value.passPhrase
          : passPhrase // ignore: cast_nullable_to_non_nullable
              as String,
      creatingNmemonic: null == creatingNmemonic
          ? _value.creatingNmemonic
          : creatingNmemonic // ignore: cast_nullable_to_non_nullable
              as bool,
      errCreatingNmemonic: null == errCreatingNmemonic
          ? _value.errCreatingNmemonic
          : errCreatingNmemonic // ignore: cast_nullable_to_non_nullable
              as String,
      saving: null == saving
          ? _value.saving
          : saving // ignore: cast_nullable_to_non_nullable
              as bool,
      errSaving: null == errSaving
          ? _value.errSaving
          : errSaving // ignore: cast_nullable_to_non_nullable
              as String,
      saved: null == saved
          ? _value.saved
          : saved // ignore: cast_nullable_to_non_nullable
              as bool,
      walletLabel: freezed == walletLabel
          ? _value.walletLabel
          : walletLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      savedWallet: freezed == savedWallet
          ? _value.savedWallet
          : savedWallet // ignore: cast_nullable_to_non_nullable
              as Wallet?,
    ));
  }
}

/// @nodoc

class _$CreateWalletStateImpl extends _CreateWalletState {
  const _$CreateWalletStateImpl(
      {final List<String>? mnemonic,
      this.passPhrase = '',
      this.creatingNmemonic = true,
      this.errCreatingNmemonic = '',
      this.saving = false,
      this.errSaving = '',
      this.saved = false,
      this.walletLabel,
      this.savedWallet})
      : _mnemonic = mnemonic,
        super._();

/**
     * 
     * SENSITIVE
     * 
     */
  final List<String>? _mnemonic;
/**
     * 
     * SENSITIVE
     * 
     */
  @override
  List<String>? get mnemonic {
    final value = _mnemonic;
    if (value == null) return null;
    if (_mnemonic is EqualUnmodifiableListView) return _mnemonic;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey()
  final String passPhrase;
/**
     * 
     * SENSITIVE
     * 
     */
  @override
  @JsonKey()
  final bool creatingNmemonic;
  @override
  @JsonKey()
  final String errCreatingNmemonic;
  @override
  @JsonKey()
  final bool saving;
  @override
  @JsonKey()
  final String errSaving;
  @override
  @JsonKey()
  final bool saved;
  @override
  final String? walletLabel;
  @override
  final Wallet? savedWallet;

  @override
  String toString() {
    return 'CreateWalletState(mnemonic: $mnemonic, passPhrase: $passPhrase, creatingNmemonic: $creatingNmemonic, errCreatingNmemonic: $errCreatingNmemonic, saving: $saving, errSaving: $errSaving, saved: $saved, walletLabel: $walletLabel, savedWallet: $savedWallet)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CreateWalletStateImpl &&
            const DeepCollectionEquality().equals(other._mnemonic, _mnemonic) &&
            (identical(other.passPhrase, passPhrase) ||
                other.passPhrase == passPhrase) &&
            (identical(other.creatingNmemonic, creatingNmemonic) ||
                other.creatingNmemonic == creatingNmemonic) &&
            (identical(other.errCreatingNmemonic, errCreatingNmemonic) ||
                other.errCreatingNmemonic == errCreatingNmemonic) &&
            (identical(other.saving, saving) || other.saving == saving) &&
            (identical(other.errSaving, errSaving) ||
                other.errSaving == errSaving) &&
            (identical(other.saved, saved) || other.saved == saved) &&
            (identical(other.walletLabel, walletLabel) ||
                other.walletLabel == walletLabel) &&
            (identical(other.savedWallet, savedWallet) ||
                other.savedWallet == savedWallet));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_mnemonic),
      passPhrase,
      creatingNmemonic,
      errCreatingNmemonic,
      saving,
      errSaving,
      saved,
      walletLabel,
      savedWallet);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CreateWalletStateImplCopyWith<_$CreateWalletStateImpl> get copyWith =>
      __$$CreateWalletStateImplCopyWithImpl<_$CreateWalletStateImpl>(
          this, _$identity);
}

abstract class _CreateWalletState extends CreateWalletState {
  const factory _CreateWalletState(
      {final List<String>? mnemonic,
      final String passPhrase,
      final bool creatingNmemonic,
      final String errCreatingNmemonic,
      final bool saving,
      final String errSaving,
      final bool saved,
      final String? walletLabel,
      final Wallet? savedWallet}) = _$CreateWalletStateImpl;
  const _CreateWalletState._() : super._();

  @override
  /**
     * 
     * SENSITIVE
     * 
     */
  List<String>? get mnemonic;
  @override
  String get passPhrase;
  @override
  /**
     * 
     * SENSITIVE
     * 
     */
  bool get creatingNmemonic;
  @override
  String get errCreatingNmemonic;
  @override
  bool get saving;
  @override
  String get errSaving;
  @override
  bool get saved;
  @override
  String? get walletLabel;
  @override
  Wallet? get savedWallet;
  @override
  @JsonKey(ignore: true)
  _$$CreateWalletStateImplCopyWith<_$CreateWalletStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

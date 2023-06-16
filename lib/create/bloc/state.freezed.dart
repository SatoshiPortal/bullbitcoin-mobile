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
  List<String>? get mnemonic => throw _privateConstructorUsedError;
  bool get creatingNmemonic => throw _privateConstructorUsedError;
  String get errCreatingNmemonic => throw _privateConstructorUsedError;
  String get passPhase => throw _privateConstructorUsedError;
  bool get saving => throw _privateConstructorUsedError;
  String get errSaving => throw _privateConstructorUsedError;
  bool get saved => throw _privateConstructorUsedError;
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
      bool creatingNmemonic,
      String errCreatingNmemonic,
      String passPhase,
      bool saving,
      String errSaving,
      bool saved,
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
    Object? creatingNmemonic = null,
    Object? errCreatingNmemonic = null,
    Object? passPhase = null,
    Object? saving = null,
    Object? errSaving = null,
    Object? saved = null,
    Object? savedWallet = freezed,
  }) {
    return _then(_value.copyWith(
      mnemonic: freezed == mnemonic
          ? _value.mnemonic
          : mnemonic // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      creatingNmemonic: null == creatingNmemonic
          ? _value.creatingNmemonic
          : creatingNmemonic // ignore: cast_nullable_to_non_nullable
              as bool,
      errCreatingNmemonic: null == errCreatingNmemonic
          ? _value.errCreatingNmemonic
          : errCreatingNmemonic // ignore: cast_nullable_to_non_nullable
              as String,
      passPhase: null == passPhase
          ? _value.passPhase
          : passPhase // ignore: cast_nullable_to_non_nullable
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
abstract class _$$_CreateWalletStateCopyWith<$Res>
    implements $CreateWalletStateCopyWith<$Res> {
  factory _$$_CreateWalletStateCopyWith(_$_CreateWalletState value,
          $Res Function(_$_CreateWalletState) then) =
      __$$_CreateWalletStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<String>? mnemonic,
      bool creatingNmemonic,
      String errCreatingNmemonic,
      String passPhase,
      bool saving,
      String errSaving,
      bool saved,
      Wallet? savedWallet});

  @override
  $WalletCopyWith<$Res>? get savedWallet;
}

/// @nodoc
class __$$_CreateWalletStateCopyWithImpl<$Res>
    extends _$CreateWalletStateCopyWithImpl<$Res, _$_CreateWalletState>
    implements _$$_CreateWalletStateCopyWith<$Res> {
  __$$_CreateWalletStateCopyWithImpl(
      _$_CreateWalletState _value, $Res Function(_$_CreateWalletState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mnemonic = freezed,
    Object? creatingNmemonic = null,
    Object? errCreatingNmemonic = null,
    Object? passPhase = null,
    Object? saving = null,
    Object? errSaving = null,
    Object? saved = null,
    Object? savedWallet = freezed,
  }) {
    return _then(_$_CreateWalletState(
      mnemonic: freezed == mnemonic
          ? _value._mnemonic
          : mnemonic // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      creatingNmemonic: null == creatingNmemonic
          ? _value.creatingNmemonic
          : creatingNmemonic // ignore: cast_nullable_to_non_nullable
              as bool,
      errCreatingNmemonic: null == errCreatingNmemonic
          ? _value.errCreatingNmemonic
          : errCreatingNmemonic // ignore: cast_nullable_to_non_nullable
              as String,
      passPhase: null == passPhase
          ? _value.passPhase
          : passPhase // ignore: cast_nullable_to_non_nullable
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
      savedWallet: freezed == savedWallet
          ? _value.savedWallet
          : savedWallet // ignore: cast_nullable_to_non_nullable
              as Wallet?,
    ));
  }
}

/// @nodoc

class _$_CreateWalletState extends _CreateWalletState {
  const _$_CreateWalletState(
      {final List<String>? mnemonic,
      this.creatingNmemonic = true,
      this.errCreatingNmemonic = '',
      this.passPhase = '',
      this.saving = false,
      this.errSaving = '',
      this.saved = false,
      this.savedWallet})
      : _mnemonic = mnemonic,
        super._();

  final List<String>? _mnemonic;
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
  final bool creatingNmemonic;
  @override
  @JsonKey()
  final String errCreatingNmemonic;
  @override
  @JsonKey()
  final String passPhase;
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
  final Wallet? savedWallet;

  @override
  String toString() {
    return 'CreateWalletState(mnemonic: $mnemonic, creatingNmemonic: $creatingNmemonic, errCreatingNmemonic: $errCreatingNmemonic, passPhase: $passPhase, saving: $saving, errSaving: $errSaving, saved: $saved, savedWallet: $savedWallet)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_CreateWalletState &&
            const DeepCollectionEquality().equals(other._mnemonic, _mnemonic) &&
            (identical(other.creatingNmemonic, creatingNmemonic) ||
                other.creatingNmemonic == creatingNmemonic) &&
            (identical(other.errCreatingNmemonic, errCreatingNmemonic) ||
                other.errCreatingNmemonic == errCreatingNmemonic) &&
            (identical(other.passPhase, passPhase) ||
                other.passPhase == passPhase) &&
            (identical(other.saving, saving) || other.saving == saving) &&
            (identical(other.errSaving, errSaving) ||
                other.errSaving == errSaving) &&
            (identical(other.saved, saved) || other.saved == saved) &&
            (identical(other.savedWallet, savedWallet) ||
                other.savedWallet == savedWallet));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_mnemonic),
      creatingNmemonic,
      errCreatingNmemonic,
      passPhase,
      saving,
      errSaving,
      saved,
      savedWallet);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_CreateWalletStateCopyWith<_$_CreateWalletState> get copyWith =>
      __$$_CreateWalletStateCopyWithImpl<_$_CreateWalletState>(
          this, _$identity);
}

abstract class _CreateWalletState extends CreateWalletState {
  const factory _CreateWalletState(
      {final List<String>? mnemonic,
      final bool creatingNmemonic,
      final String errCreatingNmemonic,
      final String passPhase,
      final bool saving,
      final String errSaving,
      final bool saved,
      final Wallet? savedWallet}) = _$_CreateWalletState;
  const _CreateWalletState._() : super._();

  @override
  List<String>? get mnemonic;
  @override
  bool get creatingNmemonic;
  @override
  String get errCreatingNmemonic;
  @override
  String get passPhase;
  @override
  bool get saving;
  @override
  String get errSaving;
  @override
  bool get saved;
  @override
  Wallet? get savedWallet;
  @override
  @JsonKey(ignore: true)
  _$$_CreateWalletStateCopyWith<_$_CreateWalletState> get copyWith =>
      throw _privateConstructorUsedError;
}

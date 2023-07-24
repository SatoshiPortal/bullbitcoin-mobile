// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'seed.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

Seed _$SeedFromJson(Map<String, dynamic> json) {
  return _Seed.fromJson(json);
}

/// @nodoc
mixin _$Seed {
  String get mnemonic => throw _privateConstructorUsedError;
  String get fingerprint => throw _privateConstructorUsedError;
  BBNetwork get network => throw _privateConstructorUsedError;
  List<Passphrase> get passphraseWallets => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SeedCopyWith<Seed> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SeedCopyWith<$Res> {
  factory $SeedCopyWith(Seed value, $Res Function(Seed) then) =
      _$SeedCopyWithImpl<$Res, Seed>;
  @useResult
  $Res call(
      {String mnemonic,
      String fingerprint,
      BBNetwork network,
      List<Passphrase> passphraseWallets});
}

/// @nodoc
class _$SeedCopyWithImpl<$Res, $Val extends Seed>
    implements $SeedCopyWith<$Res> {
  _$SeedCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mnemonic = null,
    Object? fingerprint = null,
    Object? network = null,
    Object? passphraseWallets = null,
  }) {
    return _then(_value.copyWith(
      mnemonic: null == mnemonic
          ? _value.mnemonic
          : mnemonic // ignore: cast_nullable_to_non_nullable
              as String,
      fingerprint: null == fingerprint
          ? _value.fingerprint
          : fingerprint // ignore: cast_nullable_to_non_nullable
              as String,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as BBNetwork,
      passphraseWallets: null == passphraseWallets
          ? _value.passphraseWallets
          : passphraseWallets // ignore: cast_nullable_to_non_nullable
              as List<Passphrase>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_SeedCopyWith<$Res> implements $SeedCopyWith<$Res> {
  factory _$$_SeedCopyWith(_$_Seed value, $Res Function(_$_Seed) then) =
      __$$_SeedCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String mnemonic,
      String fingerprint,
      BBNetwork network,
      List<Passphrase> passphraseWallets});
}

/// @nodoc
class __$$_SeedCopyWithImpl<$Res> extends _$SeedCopyWithImpl<$Res, _$_Seed>
    implements _$$_SeedCopyWith<$Res> {
  __$$_SeedCopyWithImpl(_$_Seed _value, $Res Function(_$_Seed) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mnemonic = null,
    Object? fingerprint = null,
    Object? network = null,
    Object? passphraseWallets = null,
  }) {
    return _then(_$_Seed(
      mnemonic: null == mnemonic
          ? _value.mnemonic
          : mnemonic // ignore: cast_nullable_to_non_nullable
              as String,
      fingerprint: null == fingerprint
          ? _value.fingerprint
          : fingerprint // ignore: cast_nullable_to_non_nullable
              as String,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as BBNetwork,
      passphraseWallets: null == passphraseWallets
          ? _value._passphraseWallets
          : passphraseWallets // ignore: cast_nullable_to_non_nullable
              as List<Passphrase>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_Seed extends _Seed {
  const _$_Seed(
      {this.mnemonic = '',
      this.fingerprint = '',
      required this.network,
      required final List<Passphrase> passphraseWallets})
      : _passphraseWallets = passphraseWallets,
        super._();

  factory _$_Seed.fromJson(Map<String, dynamic> json) => _$$_SeedFromJson(json);

  @override
  @JsonKey()
  final String mnemonic;
  @override
  @JsonKey()
  final String fingerprint;
  @override
  final BBNetwork network;
  final List<Passphrase> _passphraseWallets;
  @override
  List<Passphrase> get passphraseWallets {
    if (_passphraseWallets is EqualUnmodifiableListView)
      return _passphraseWallets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_passphraseWallets);
  }

  @override
  String toString() {
    return 'Seed(mnemonic: $mnemonic, fingerprint: $fingerprint, network: $network, passphraseWallets: $passphraseWallets)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_Seed &&
            (identical(other.mnemonic, mnemonic) ||
                other.mnemonic == mnemonic) &&
            (identical(other.fingerprint, fingerprint) ||
                other.fingerprint == fingerprint) &&
            (identical(other.network, network) || other.network == network) &&
            const DeepCollectionEquality()
                .equals(other._passphraseWallets, _passphraseWallets));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, mnemonic, fingerprint, network,
      const DeepCollectionEquality().hash(_passphraseWallets));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_SeedCopyWith<_$_Seed> get copyWith =>
      __$$_SeedCopyWithImpl<_$_Seed>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_SeedToJson(
      this,
    );
  }
}

abstract class _Seed extends Seed {
  const factory _Seed(
      {final String mnemonic,
      final String fingerprint,
      required final BBNetwork network,
      required final List<Passphrase> passphraseWallets}) = _$_Seed;
  const _Seed._() : super._();

  factory _Seed.fromJson(Map<String, dynamic> json) = _$_Seed.fromJson;

  @override
  String get mnemonic;
  @override
  String get fingerprint;
  @override
  BBNetwork get network;
  @override
  List<Passphrase> get passphraseWallets;
  @override
  @JsonKey(ignore: true)
  _$$_SeedCopyWith<_$_Seed> get copyWith => throw _privateConstructorUsedError;
}

Passphrase _$PassphraseFromJson(Map<String, dynamic> json) {
  return _Passphrase.fromJson(json);
}

/// @nodoc
mixin _$Passphrase {
  String get passphrase => throw _privateConstructorUsedError;
  String get fingerprint => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PassphraseCopyWith<Passphrase> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PassphraseCopyWith<$Res> {
  factory $PassphraseCopyWith(
          Passphrase value, $Res Function(Passphrase) then) =
      _$PassphraseCopyWithImpl<$Res, Passphrase>;
  @useResult
  $Res call({String passphrase, String fingerprint});
}

/// @nodoc
class _$PassphraseCopyWithImpl<$Res, $Val extends Passphrase>
    implements $PassphraseCopyWith<$Res> {
  _$PassphraseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? passphrase = null,
    Object? fingerprint = null,
  }) {
    return _then(_value.copyWith(
      passphrase: null == passphrase
          ? _value.passphrase
          : passphrase // ignore: cast_nullable_to_non_nullable
              as String,
      fingerprint: null == fingerprint
          ? _value.fingerprint
          : fingerprint // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_PassphraseCopyWith<$Res>
    implements $PassphraseCopyWith<$Res> {
  factory _$$_PassphraseCopyWith(
          _$_Passphrase value, $Res Function(_$_Passphrase) then) =
      __$$_PassphraseCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String passphrase, String fingerprint});
}

/// @nodoc
class __$$_PassphraseCopyWithImpl<$Res>
    extends _$PassphraseCopyWithImpl<$Res, _$_Passphrase>
    implements _$$_PassphraseCopyWith<$Res> {
  __$$_PassphraseCopyWithImpl(
      _$_Passphrase _value, $Res Function(_$_Passphrase) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? passphrase = null,
    Object? fingerprint = null,
  }) {
    return _then(_$_Passphrase(
      passphrase: null == passphrase
          ? _value.passphrase
          : passphrase // ignore: cast_nullable_to_non_nullable
              as String,
      fingerprint: null == fingerprint
          ? _value.fingerprint
          : fingerprint // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_Passphrase extends _Passphrase {
  const _$_Passphrase({this.passphrase = '', required this.fingerprint})
      : super._();

  factory _$_Passphrase.fromJson(Map<String, dynamic> json) =>
      _$$_PassphraseFromJson(json);

  @override
  @JsonKey()
  final String passphrase;
  @override
  final String fingerprint;

  @override
  String toString() {
    return 'Passphrase(passphrase: $passphrase, fingerprint: $fingerprint)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_Passphrase &&
            (identical(other.passphrase, passphrase) ||
                other.passphrase == passphrase) &&
            (identical(other.fingerprint, fingerprint) ||
                other.fingerprint == fingerprint));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, passphrase, fingerprint);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_PassphraseCopyWith<_$_Passphrase> get copyWith =>
      __$$_PassphraseCopyWithImpl<_$_Passphrase>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_PassphraseToJson(
      this,
    );
  }
}

abstract class _Passphrase extends Passphrase {
  const factory _Passphrase(
      {final String passphrase,
      required final String fingerprint}) = _$_Passphrase;
  const _Passphrase._() : super._();

  factory _Passphrase.fromJson(Map<String, dynamic> json) =
      _$_Passphrase.fromJson;

  @override
  String get passphrase;
  @override
  String get fingerprint;
  @override
  @JsonKey(ignore: true)
  _$$_PassphraseCopyWith<_$_Passphrase> get copyWith =>
      throw _privateConstructorUsedError;
}

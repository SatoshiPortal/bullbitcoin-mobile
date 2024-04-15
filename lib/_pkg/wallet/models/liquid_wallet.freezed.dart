// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'liquid_wallet.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

LiquidWallet _$LiquidWalletFromJson(Map<String, dynamic> json) {
  return _LiquidWallet.fromJson(json);
}

/// @nodoc
mixin _$LiquidWallet {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int get balance => throw _privateConstructorUsedError;
  WalletType get type => throw _privateConstructorUsedError;
  NetworkType get network => throw _privateConstructorUsedError;
  bool get backupTested => throw _privateConstructorUsedError;
  DateTime? get lastSync => throw _privateConstructorUsedError;
  DateTime? get lastBackupTested => throw _privateConstructorUsedError;
  String get mnemonic => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  lwk.Wallet? get lwkWallet => throw _privateConstructorUsedError;
  String get seedFingerprint => throw _privateConstructorUsedError;
  BitcoinScriptType get bipPath => throw _privateConstructorUsedError;
  ImportTypes get importType => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $LiquidWalletCopyWith<LiquidWallet> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LiquidWalletCopyWith<$Res> {
  factory $LiquidWalletCopyWith(
          LiquidWallet value, $Res Function(LiquidWallet) then) =
      _$LiquidWalletCopyWithImpl<$Res, LiquidWallet>;
  @useResult
  $Res call(
      {String id,
      String name,
      int balance,
      WalletType type,
      NetworkType network,
      bool backupTested,
      DateTime? lastSync,
      DateTime? lastBackupTested,
      String mnemonic,
      @JsonKey(includeFromJson: false, includeToJson: false)
      lwk.Wallet? lwkWallet,
      String seedFingerprint,
      BitcoinScriptType bipPath,
      ImportTypes importType});
}

/// @nodoc
class _$LiquidWalletCopyWithImpl<$Res, $Val extends LiquidWallet>
    implements $LiquidWalletCopyWith<$Res> {
  _$LiquidWalletCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? balance = null,
    Object? type = null,
    Object? network = null,
    Object? backupTested = null,
    Object? lastSync = freezed,
    Object? lastBackupTested = freezed,
    Object? mnemonic = null,
    Object? lwkWallet = freezed,
    Object? seedFingerprint = null,
    Object? bipPath = null,
    Object? importType = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      balance: null == balance
          ? _value.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as int,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as WalletType,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as NetworkType,
      backupTested: null == backupTested
          ? _value.backupTested
          : backupTested // ignore: cast_nullable_to_non_nullable
              as bool,
      lastSync: freezed == lastSync
          ? _value.lastSync
          : lastSync // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastBackupTested: freezed == lastBackupTested
          ? _value.lastBackupTested
          : lastBackupTested // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      mnemonic: null == mnemonic
          ? _value.mnemonic
          : mnemonic // ignore: cast_nullable_to_non_nullable
              as String,
      lwkWallet: freezed == lwkWallet
          ? _value.lwkWallet
          : lwkWallet // ignore: cast_nullable_to_non_nullable
              as lwk.Wallet?,
      seedFingerprint: null == seedFingerprint
          ? _value.seedFingerprint
          : seedFingerprint // ignore: cast_nullable_to_non_nullable
              as String,
      bipPath: null == bipPath
          ? _value.bipPath
          : bipPath // ignore: cast_nullable_to_non_nullable
              as BitcoinScriptType,
      importType: null == importType
          ? _value.importType
          : importType // ignore: cast_nullable_to_non_nullable
              as ImportTypes,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$LiquidWalletImplCopyWith<$Res>
    implements $LiquidWalletCopyWith<$Res> {
  factory _$$LiquidWalletImplCopyWith(
          _$LiquidWalletImpl value, $Res Function(_$LiquidWalletImpl) then) =
      __$$LiquidWalletImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      int balance,
      WalletType type,
      NetworkType network,
      bool backupTested,
      DateTime? lastSync,
      DateTime? lastBackupTested,
      String mnemonic,
      @JsonKey(includeFromJson: false, includeToJson: false)
      lwk.Wallet? lwkWallet,
      String seedFingerprint,
      BitcoinScriptType bipPath,
      ImportTypes importType});
}

/// @nodoc
class __$$LiquidWalletImplCopyWithImpl<$Res>
    extends _$LiquidWalletCopyWithImpl<$Res, _$LiquidWalletImpl>
    implements _$$LiquidWalletImplCopyWith<$Res> {
  __$$LiquidWalletImplCopyWithImpl(
      _$LiquidWalletImpl _value, $Res Function(_$LiquidWalletImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? balance = null,
    Object? type = null,
    Object? network = null,
    Object? backupTested = null,
    Object? lastSync = freezed,
    Object? lastBackupTested = freezed,
    Object? mnemonic = null,
    Object? lwkWallet = freezed,
    Object? seedFingerprint = null,
    Object? bipPath = null,
    Object? importType = null,
  }) {
    return _then(_$LiquidWalletImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      balance: null == balance
          ? _value.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as int,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as WalletType,
      network: null == network
          ? _value.network
          : network // ignore: cast_nullable_to_non_nullable
              as NetworkType,
      backupTested: null == backupTested
          ? _value.backupTested
          : backupTested // ignore: cast_nullable_to_non_nullable
              as bool,
      lastSync: freezed == lastSync
          ? _value.lastSync
          : lastSync // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastBackupTested: freezed == lastBackupTested
          ? _value.lastBackupTested
          : lastBackupTested // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      mnemonic: null == mnemonic
          ? _value.mnemonic
          : mnemonic // ignore: cast_nullable_to_non_nullable
              as String,
      lwkWallet: freezed == lwkWallet
          ? _value.lwkWallet
          : lwkWallet // ignore: cast_nullable_to_non_nullable
              as lwk.Wallet?,
      seedFingerprint: null == seedFingerprint
          ? _value.seedFingerprint
          : seedFingerprint // ignore: cast_nullable_to_non_nullable
              as String,
      bipPath: null == bipPath
          ? _value.bipPath
          : bipPath // ignore: cast_nullable_to_non_nullable
              as BitcoinScriptType,
      importType: null == importType
          ? _value.importType
          : importType // ignore: cast_nullable_to_non_nullable
              as ImportTypes,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$LiquidWalletImpl extends _LiquidWallet {
  _$LiquidWalletImpl(
      {required this.id,
      required this.name,
      required this.balance,
      required this.type,
      required this.network,
      this.backupTested = false,
      this.lastSync,
      this.lastBackupTested,
      this.mnemonic = '',
      @JsonKey(includeFromJson: false, includeToJson: false) this.lwkWallet,
      required this.seedFingerprint,
      this.bipPath = BitcoinScriptType.bip84,
      this.importType = ImportTypes.words12})
      : super._();

  factory _$LiquidWalletImpl.fromJson(Map<String, dynamic> json) =>
      _$$LiquidWalletImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final int balance;
  @override
  final WalletType type;
  @override
  final NetworkType network;
  @override
  @JsonKey()
  final bool backupTested;
  @override
  final DateTime? lastSync;
  @override
  final DateTime? lastBackupTested;
  @override
  @JsonKey()
  final String mnemonic;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final lwk.Wallet? lwkWallet;
  @override
  final String seedFingerprint;
  @override
  @JsonKey()
  final BitcoinScriptType bipPath;
  @override
  @JsonKey()
  final ImportTypes importType;

  @override
  String toString() {
    return 'LiquidWallet(id: $id, name: $name, balance: $balance, type: $type, network: $network, backupTested: $backupTested, lastSync: $lastSync, lastBackupTested: $lastBackupTested, mnemonic: $mnemonic, lwkWallet: $lwkWallet, seedFingerprint: $seedFingerprint, bipPath: $bipPath, importType: $importType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LiquidWalletImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.balance, balance) || other.balance == balance) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.network, network) || other.network == network) &&
            (identical(other.backupTested, backupTested) ||
                other.backupTested == backupTested) &&
            (identical(other.lastSync, lastSync) ||
                other.lastSync == lastSync) &&
            (identical(other.lastBackupTested, lastBackupTested) ||
                other.lastBackupTested == lastBackupTested) &&
            (identical(other.mnemonic, mnemonic) ||
                other.mnemonic == mnemonic) &&
            (identical(other.lwkWallet, lwkWallet) ||
                other.lwkWallet == lwkWallet) &&
            (identical(other.seedFingerprint, seedFingerprint) ||
                other.seedFingerprint == seedFingerprint) &&
            (identical(other.bipPath, bipPath) || other.bipPath == bipPath) &&
            (identical(other.importType, importType) ||
                other.importType == importType));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      balance,
      type,
      network,
      backupTested,
      lastSync,
      lastBackupTested,
      mnemonic,
      lwkWallet,
      seedFingerprint,
      bipPath,
      importType);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$LiquidWalletImplCopyWith<_$LiquidWalletImpl> get copyWith =>
      __$$LiquidWalletImplCopyWithImpl<_$LiquidWalletImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LiquidWalletImplToJson(
      this,
    );
  }
}

abstract class _LiquidWallet extends LiquidWallet {
  factory _LiquidWallet(
      {required final String id,
      required final String name,
      required final int balance,
      required final WalletType type,
      required final NetworkType network,
      final bool backupTested,
      final DateTime? lastSync,
      final DateTime? lastBackupTested,
      final String mnemonic,
      @JsonKey(includeFromJson: false, includeToJson: false)
      final lwk.Wallet? lwkWallet,
      required final String seedFingerprint,
      final BitcoinScriptType bipPath,
      final ImportTypes importType}) = _$LiquidWalletImpl;
  _LiquidWallet._() : super._();

  factory _LiquidWallet.fromJson(Map<String, dynamic> json) =
      _$LiquidWalletImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  int get balance;
  @override
  WalletType get type;
  @override
  NetworkType get network;
  @override
  bool get backupTested;
  @override
  DateTime? get lastSync;
  @override
  DateTime? get lastBackupTested;
  @override
  String get mnemonic;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  lwk.Wallet? get lwkWallet;
  @override
  String get seedFingerprint;
  @override
  BitcoinScriptType get bipPath;
  @override
  ImportTypes get importType;
  @override
  @JsonKey(ignore: true)
  _$$LiquidWalletImplCopyWith<_$LiquidWalletImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

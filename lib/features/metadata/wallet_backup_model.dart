import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_backup_model.freezed.dart';
part 'wallet_backup_model.g.dart';

enum KeyRole { main, recovery, inheritance, cosigning }

enum KeyType { internal, external, thirdParty }

enum KeyStatus { active, inactive, revoked }

enum Network { bitcoin, testnet, signet, regtest }

@freezed
sealed class WalletBackupModel with _$WalletBackupModel {
  const factory WalletBackupModel({
    @Default(null) int? version,
    @Default(null) String? name,
    @Default(null) String? description,
    @Default([]) List<Account> accounts,
    required Network network,
    @Default({}) Map<String, dynamic> proprietary,
  }) = _WalletBackupModel;
  const WalletBackupModel._();

  factory WalletBackupModel.fromJson(Map<String, dynamic> json) =>
      _$WalletBackupModelFromJson(json);
}

@freezed
sealed class Account with _$Account {
  const factory Account({
    @Default(null) String? name,
    @Default(null) String? description,
    @Default(null) bool? active,
    required String descriptor,
    @Default(null) int? receiveIndex,
    @Default(null) int? changeIndex,
    @Default(null) int? timestamp,
    @Default({}) Map<String, Key> keys,
    @Default({}) Map<String, dynamic> labels,
    @Default([]) List<String> transactions,
    @Default([]) List<String> psbts,
    @Default(null) String? bip39Mnemonic, // TODO: What is the usecase ?
    @Default({}) Map<String, dynamic> proprietary,
  }) = _Account;
  const Account._();

  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);
}

@freezed
sealed class Key with _$Key {
  const factory Key({
    required String key,
    @Default(null) String? alias,
    @Default(null) KeyRole? role,
    @Default(null) KeyType? keyType,
    @Default(null) KeyStatus? keyStatus,
    @Default(null) String? bip85DerivationPath,
  }) = _Key;
  const Key._();

  factory Key.fromJson(Map<String, dynamic> json) => _$KeyFromJson(json);
}

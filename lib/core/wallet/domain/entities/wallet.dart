import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet.freezed.dart';

enum Network {
  bitcoinMainnet(
    coinType: 0,
    isBitcoin: true,
    isLiquid: false,
    isMainnet: true,
    isTestnet: false,
  ),
  bitcoinTestnet(
    coinType: 1,
    isBitcoin: true,
    isLiquid: false,
    isMainnet: false,
    isTestnet: true,
  ),
  liquidMainnet(
    coinType: 1776,
    isBitcoin: false,
    isLiquid: true,
    isMainnet: true,
    isTestnet: false,
  ),
  liquidTestnet(
    coinType: 1,
    isBitcoin: false,
    isLiquid: true,
    isMainnet: false,
    isTestnet: true,
  );

  final int coinType;
  final bool isBitcoin;
  final bool isLiquid;
  final bool isMainnet;
  final bool isTestnet;

  const Network({
    required this.coinType,
    required this.isBitcoin,
    required this.isLiquid,
    required this.isMainnet,
    required this.isTestnet,
  });

  factory Network.fromName(String name) {
    return Network.values.firstWhere((network) => network.name == name);
  }

  factory Network.fromEnvironment({
    required bool isTestnet,
    required bool isLiquid,
  }) {
    if (isLiquid) {
      return isTestnet ? liquidTestnet : liquidMainnet;
    } else {
      return isTestnet ? bitcoinTestnet : bitcoinMainnet;
    }
  }
}

enum ScriptType {
  bip84(purpose: 84),
  bip49(purpose: 49),
  bip44(purpose: 44);

  final int purpose;

  const ScriptType({required this.purpose});

  static ScriptType fromName(String name) {
    return ScriptType.values.firstWhere((script) => script.name == name);
  }
}

@freezed
abstract class Wallet with _$Wallet {
  const factory Wallet({
    required String origin,
    @Default('') String label,
    required Network network,
    @Default(false) bool isDefault,
    // The fingerprint of the BIP32 root/master key (if a seed was used to derive the wallet)
    @Default('') String masterFingerprint,
    required String xpubFingerprint,
    required ScriptType scriptType,
    required String xpub,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required WalletSource source,
    required BigInt balanceSat,
    @Default(false) bool isEncryptedVaultTested,
    @Default(false) bool isPhysicalBackupTested,
    DateTime? latestEncryptedBackup,
    DateTime? latestPhysicalBackup,
    // We should probably store lastSwapIndex here
    // reason is that when we store wallet metadata as part of a backup, its easy to get the last index
    // otherwise we have to store all swap metadata as part of the backup as well, which is not ideal
  }) = _Wallet;
  const Wallet._();

  String get id => origin;

  String getWalletTypeString() {
    return switch (network) {
      Network.bitcoinMainnet || Network.bitcoinTestnet => 'Bitcoin network',
      Network.liquidMainnet ||
      Network.liquidTestnet => 'Liquid and Lightning network',
    };
  }

  String getLabel() {
    if (!isDefault) return label;

    return switch (network) {
      Network.bitcoinMainnet ||
      Network.bitcoinTestnet => 'Secure Bitcoin wallet',
      Network.liquidMainnet ||
      Network.liquidTestnet => 'Instant payments wallet',
    };
  }

  bool get isTestnet {
    return network == Network.bitcoinTestnet ||
        network == Network.liquidTestnet;
  }

  bool get isLiquid {
    return network == Network.liquidMainnet || network == Network.liquidTestnet;
  }

  bool get isWatchOnly => switch (source) {
    WalletSource.xpub || WalletSource.coldcard => true,
    _ => false,
  };
}

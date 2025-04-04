import 'package:bb_mobile/core/wallet/domain/entity/transaction.dart';
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

enum WalletSource {
  mnemonic,
  xpub,
  descriptors,
  coldcard;

  static WalletSource fromName(String name) {
    return WalletSource.values.firstWhere((source) => source.name == name);
  }
}

@freezed
class Wallet with _$Wallet {
  const factory Wallet({
    required String id,
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
    @Default([]) List<Transaction> recentTransactions,
    @Default(false) bool isEncryptedVaultTested,
    @Default(false) bool isPhysicalBackupTested,
    DateTime? latestEncryptedBackup,
    DateTime? latestPhysicalBackup,
    // We should probably store lastSwapIndex here
    // reason is that when we store wallet metadata as part of a backup, its easy to get the last index
    // otherwise we have to store all swap metadata as part of the backup as well, which is not ideal
  }) = _Wallet;
  const Wallet._();

  String getWalletTypeString() {
    String str = '';

    switch (network) {
      case Network.bitcoinMainnet:
      case Network.bitcoinTestnet:
        str = 'Bitcoin network';

      case Network.liquidMainnet:
      case Network.liquidTestnet:
        str = 'Liquid and Lightning network';
    }

    return str;
  }

  String getLabel() {
    if (!isDefault) return label;

    switch (network) {
      case Network.bitcoinMainnet:
      case Network.bitcoinTestnet:
        return 'Secure Bitcoin wallet';

      case Network.liquidMainnet:
      case Network.liquidTestnet:
        return 'Instant payments wallet';
    }
  }

  bool isTestnet() {
    return network == Network.bitcoinTestnet ||
        network == Network.liquidTestnet;
  }

  bool isInstant() {
    return network == Network.liquidMainnet || network == Network.liquidTestnet;
  }

  bool watchOnly() {
    switch (source) {
      case WalletSource.xpub:
      case WalletSource.coldcard:
        return true;
      default:
        return false;
    }
  }

  String getOrigin() {
    final networkPath = network == Network.bitcoinMainnet
        ? '0h'
        : network == Network.liquidMainnet
            ? '1667h'
            : '1h';

    String scriptPath = '';
    switch (scriptType) {
      case ScriptType.bip84:
        scriptPath = '84h';
      case ScriptType.bip49:
        scriptPath = '49h';
      case ScriptType.bip44:
        scriptPath = '44h';
    }

    const String accountPath = '0h';

    return '[$masterFingerprint/$scriptPath/$networkPath/$accountPath]';
  }
}

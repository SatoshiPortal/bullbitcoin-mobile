import 'package:bb_mobile/core/entities/signer_entity.dart';
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

  factory ScriptType.fromName(String name) {
    return ScriptType.values.firstWhere((script) => script.name == name);
  }

  factory ScriptType.fromExtendedPublicKey(String extendedPublicKey) {
    switch (extendedPublicKey.substring(0, 4)) {
      case 'xpub':
        return ScriptType.bip44;
      case 'ypub':
        return ScriptType.bip49;
      case 'zpub':
        return ScriptType.bip84;
      default:
        throw Exception('Invalid extended public key');
    }
  }
}

@freezed
abstract class Wallet with _$Wallet {
  const factory Wallet({
    required String origin,
    String? label,
    required Network network,
    @Default(false) bool isDefault,
    // The fingerprint of the BIP32 root/master key (if a seed was used to derive the wallet)
    @Default('') String masterFingerprint,
    required String xpubFingerprint,
    required ScriptType scriptType,
    required String xpub,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required SignerEntity signer,
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
  String get addressType {
    if (isLiquid) {
      return 'Confidential Segwit';
    }

    return switch (scriptType) {
      ScriptType.bip84 => 'Native Segwit',
      ScriptType.bip49 => 'Nested Segwit',
      ScriptType.bip44 => 'Legacy',
    };
  }

  String get walletTypeString {
    String name = switch (network) {
      Network.bitcoinMainnet || Network.bitcoinTestnet => 'Bitcoin network',
      Network.liquidMainnet ||
      Network.liquidTestnet => 'Liquid and Lightning network',
    };
    if (isWatchOnly) name = 'Watch-Only';
    if (isWatchSigner) name = 'Watch-Signer';
    return name;
  }

  String get networkString {
    return switch (network) {
      Network.bitcoinMainnet => 'Bitcoin Network',
      Network.bitcoinTestnet => 'Bitcoin Testnet',
      Network.liquidMainnet => 'Liquid Network',
      Network.liquidTestnet => 'Liquid Testnet',
    };
  }

  String get displayLabel {
    if (!isDefault) return label ?? origin;

    return switch (network) {
      Network.bitcoinMainnet || Network.bitcoinTestnet => 'Secure Bitcoin',
      Network.liquidMainnet || Network.liquidTestnet => 'Instant payments',
    };
  }

  bool get isTestnet {
    return network == Network.bitcoinTestnet ||
        network == Network.liquidTestnet;
  }

  bool get isLiquid {
    return network == Network.liquidMainnet || network == Network.liquidTestnet;
  }

  String get derivationPath {
    // Find the content between [ and ]
    final startBracket = externalPublicDescriptor.indexOf('[');
    final endBracket = externalPublicDescriptor.indexOf(']');

    if (startBracket == -1 || endBracket == -1 || startBracket >= endBracket) {
      // Fallback to hardcoded path if descriptor doesn't contain path info
      return "m / ${scriptType.purpose}' / ${network.coinType}' / 0'";
    }

    // Extract fingerprint/path portion
    final keyOrigin = externalPublicDescriptor.substring(
      startBracket + 1,
      endBracket,
    );

    // Split by / to separate fingerprint from path
    final parts = keyOrigin.split('/');

    if (parts.length < 2) {
      // Invalid format, use fallback
      return "m / ${scriptType.purpose}' / ${network.coinType}' / 0'";
    }

    // Skip first part (fingerprint) and join the rest
    final pathParts = parts.skip(1).toList();

    // Construct the derivation path from the parts
    return "m / ${pathParts.join(' / ')}";
  }

  bool get isWatchOnly => signer == SignerEntity.none;
  bool get isWatchSigner => signer == SignerEntity.remote;
  bool get signsLocally => signer == SignerEntity.local;
  bool get signsRemotely => isWatchSigner;
}

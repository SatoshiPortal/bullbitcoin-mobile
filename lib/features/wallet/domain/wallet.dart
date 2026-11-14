import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:flutter/material.dart';
import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet.freezed.dart';

enum Network {
  bitcoinMainnet(coinType: 0, isBitcoin: true, environment: NetworkEnv.mainnet),
  bitcoinTestnet(coinType: 1, isBitcoin: true, environment: NetworkEnv.testnet),
  bitcoinRegtest(coinType: 1, isBitcoin: true, environment: NetworkEnv.regtest),
  liquidMainnet(
    coinType: 1776,
    isBitcoin: false,
    environment: NetworkEnv.mainnet,
  ),
  liquidTestnet(coinType: 1, isBitcoin: false, environment: NetworkEnv.testnet),
  liquidRegtest(coinType: 1, isBitcoin: false, environment: NetworkEnv.regtest);

  final int coinType;
  final bool isBitcoin;
  final NetworkEnv environment;
  const Network({
    required this.coinType,
    required this.isBitcoin,
    required this.environment,
  });
  bool get isLiquid => !isBitcoin;
  bool get isMainnet => environment == NetworkEnv.mainnet;

  factory Network.fromName(String name) =>
      Network.values.firstWhere((network) => network.name == name);

  factory Network.fromEnvironment({
    required NetworkEnv environment,
    required bool isLiquid,
  }) => switch ((environment, isLiquid)) {
    (NetworkEnv.mainnet, false) => bitcoinMainnet,
    (NetworkEnv.testnet, false) => bitcoinTestnet,
    (NetworkEnv.regtest, false) => bitcoinRegtest,
    (NetworkEnv.mainnet, true) => liquidMainnet,
    (NetworkEnv.testnet, true) => liquidTestnet,
    (NetworkEnv.regtest, true) => liquidRegtest,
    (NetworkEnv.signet, _) => throw const UnsupportedNetworkException(),
  };

  /// Historical protocol bridge. New networks must be supported explicitly by
  /// the protocol owner before it can use a binary SDK or service API.
  bool requireHistoricalTestnet() => switch (this) {
    bitcoinMainnet || liquidMainnet => false,
    bitcoinTestnet || liquidTestnet => true,
    bitcoinRegtest ||
    liquidRegtest => throw const UnsupportedNetworkException(),
  };
}

final class UnsupportedNetworkException implements Exception {
  const UnsupportedNetworkException();
}

final class InvalidWalletAddressException implements Exception {
  const InvalidWalletAddressException();
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
    required SignerDeviceEntity? signerDevice,
    required BigInt? balanceSat,
    // Confirmed-only component of balanceSat (excludes trusted/untrusted
    // pending and immature funds). Nullable/optional so every existing
    // construction site doesn't need updating at once; consumers that care
    // about "genuinely spendable now" (e.g. payjoin eligibility, which needs
    // a real confirmed UTXO to contribute as a proposal input) must treat
    // null as "not yet known" rather than falling back to balanceSat, or
    // they silently reintroduce the total-vs-confirmed gap this exists to
    // close.
    BigInt? confirmedBalanceSat,
    @Default(false) bool isEncryptedVaultTested,
    @Default(false) bool isPhysicalBackupTested,
    DateTime? latestEncryptedBackup,
    DateTime? latestPhysicalBackup,
    // We should probably store lastSwapIndex here
    // reason is that when we store wallet metadata as part of a backup, its easy to get the last index
    // otherwise we have to store all swap metadata as part of the backup as well, which is not ideal
  }) = _Wallet;
  const Wallet._();

  /// Native state could not be read; null is unknown, never a zero balance.
  bool get unavailable => balanceSat == null;

  String get id => switch (network) {
    Network.bitcoinRegtest || Network.liquidRegtest => '$origin:regtest',
    _ => origin,
  };
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
      Network.bitcoinMainnet ||
      Network.bitcoinTestnet ||
      Network.bitcoinRegtest => 'Bitcoin network',
      Network.liquidMainnet ||
      Network.liquidTestnet ||
      Network.liquidRegtest => 'Liquid and Lightning',
    };
    if (isWatchOnly) name = 'Watch-Only';
    if (isWatchSigner) name = 'Watch-Signer';
    return name;
  }

  String get networkString {
    return switch (network) {
      Network.bitcoinMainnet => 'Bitcoin Network',
      Network.bitcoinTestnet => 'Bitcoin Testnet',
      Network.bitcoinRegtest => 'Bitcoin Regtest',
      Network.liquidMainnet => 'Liquid Network',
      Network.liquidTestnet => 'Liquid Testnet',
      Network.liquidRegtest => 'Liquid Regtest',
    };
  }

  String displayLabel(BuildContext context) {
    if (!isDefault) return label ?? origin;

    return switch (network) {
      Network.bitcoinMainnet ||
      Network.bitcoinTestnet ||
      Network.bitcoinRegtest => context.loc.globalDefaultBitcoinWalletLabel,
      Network.liquidMainnet ||
      Network.liquidTestnet ||
      Network.liquidRegtest => context.loc.globalDefaultLiquidWalletLabel,
    };
  }

  bool get isLiquid => network.isLiquid;
  bool get isBitcoin => network.isBitcoin;

  String get derivationPath {
    // Find the content between [ and ]
    final startBracket = externalPublicDescriptor.indexOf('[');
    final endBracket = externalPublicDescriptor.indexOf(']');

    if (startBracket == -1 || endBracket == -1 || startBracket >= endBracket) {
      // Fallback to hardcoded path if descriptor doesn't contain path info
      return "m/${scriptType.purpose}'/${network.coinType}'/0'";
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
      return "m/${scriptType.purpose}'/${network.coinType}'/0'";
    }

    // Skip first part (fingerprint) and join the rest
    final pathParts = parts.skip(1).toList();

    // Construct the derivation path from the parts
    return "m/${pathParts.join('/')}";
  }

  bool get isWatchOnly => signer == SignerEntity.none;
  bool get isWatchSigner => signer == SignerEntity.remote;
  bool get signsLocally => signer == SignerEntity.local;
  bool get signsRemotely => isWatchSigner;
  bool get isHardwareWallet => signerDevice != null;
  bool get isBitcoinHardwareWallet => isBitcoin && isHardwareWallet;
}

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:flutter/material.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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

  int? standardAccount(String? path, Network network) {
    if (path == null) return null;
    final hardened = "[h']";
    final match = RegExp(
      '^m/$purpose$hardened/${network.coinType}$hardened/'
      r"([0-9]+)[h']$",
    ).firstMatch(path);
    final account = int.tryParse(match?.group(1) ?? '');
    return account != null && account < 0x80000000 ? account : null;
  }

  bool matchesStandardAccountPath(String? path, Network network) =>
      standardAccount(path, network) != null;
}

const standardSingleSignatureDescriptorPath = '/<0;1>/*';

@freezed
abstract class Wallet with _$Wallet {
  const factory Wallet({
    required String origin,
    String? label,
    required Network network,
    @Default(false) bool isDefault,
    required List<WalletSigner> signers,
    required ScriptType? scriptType,
    required String publicDescriptor,
    required BigInt balanceSat,
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

  String get id => origin;
  List<WalletDescriptorKey> get descriptorKeys =>
      List.unmodifiable(signers.expand((signer) => signer.descriptorKeys));
  Iterable<String> get localMasterFingerprints => signers
      .where((signer) => signer.signer == SignerEntity.local)
      .expand((signer) => signer.descriptorKeys)
      .map((key) => key.masterFingerprint)
      .where((fingerprint) => fingerprint.isNotEmpty);
  WalletSigner? get singleSigner => signers.length == 1 ? signers.single : null;
  WalletDescriptorKey? get singleDescriptorKey =>
      descriptorKeys.length == 1 ? descriptorKeys.single : null;
  String get masterFingerprint => singleDescriptorKey?.masterFingerprint ?? '';
  SignerEntity get signer => singleSigner?.signer ?? SignerEntity.none;
  SignerDeviceEntity? get signerDevice => singleSigner?.signerDevice;

  String get addressType {
    if (isLiquid) {
      return 'Confidential Segwit';
    }

    return switch (scriptType) {
      ScriptType.bip84 => 'Native Segwit',
      ScriptType.bip49 => 'Nested Segwit',
      ScriptType.bip44 => 'Legacy',
      null => 'Descriptor',
    };
  }

  String get walletTypeString {
    String name = switch (network) {
      Network.bitcoinMainnet || Network.bitcoinTestnet => 'Bitcoin network',
      Network.liquidMainnet || Network.liquidTestnet => 'Liquid and Lightning',
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

  String displayLabel(BuildContext context) {
    if (!isDefault) return label ?? origin;

    return switch (network) {
      Network.bitcoinMainnet ||
      Network.bitcoinTestnet => context.loc.globalDefaultBitcoinWalletLabel,
      Network.liquidMainnet ||
      Network.liquidTestnet => context.loc.globalDefaultLiquidWalletLabel,
    };
  }

  bool get isTestnet {
    return network == Network.bitcoinTestnet ||
        network == Network.liquidTestnet;
  }

  bool get isLiquid {
    return network == Network.liquidMainnet || network == Network.liquidTestnet;
  }

  bool get isBitcoin {
    return network == Network.bitcoinMainnet ||
        network == Network.bitcoinTestnet;
  }

  String? get derivationPath {
    final descriptorKey = singleDescriptorKey;
    if (descriptorKey != null) return descriptorKey.derivationPath;
    if (descriptorKeys.isNotEmpty) return null;

    // Find the content between [ and ]
    final startBracket = publicDescriptor.indexOf('[');
    final endBracket = publicDescriptor.indexOf(']');

    if (startBracket == -1 || endBracket == -1 || startBracket >= endBracket) {
      return _legacyDerivationPath;
    }

    // Extract fingerprint/path portion
    final keyOrigin = publicDescriptor.substring(startBracket + 1, endBracket);

    // Split by / to separate fingerprint from path
    final parts = keyOrigin.split('/');

    if (parts.length < 2) {
      return _legacyDerivationPath;
    }

    // Skip first part (fingerprint) and join the rest
    final pathParts = parts.skip(1).toList();

    // Construct the derivation path from the parts
    return "m/${pathParts.join('/')}";
  }

  String? get _legacyDerivationPath {
    final type = scriptType;
    if (type == null) return null;
    return "m/${type.purpose}'/${network.coinType}'/0'";
  }

  bool get isWatchOnly =>
      signers.every((signer) => signer.signer == SignerEntity.none);
  bool get isWatchSigner => singleSigner?.signer == SignerEntity.remote;
  bool get isStandardSingleSignatureWallet {
    final key = singleDescriptorKey;
    final type = scriptType;
    if (key == null || type == null) return false;
    if (!type.matchesStandardAccountPath(key.derivationPath, network)) {
      return false;
    }
    return isLiquid ||
        key.descriptorPath == standardSingleSignatureDescriptorPath;
  }

  bool get isStandardLocalSingleSignatureWallet {
    final signer = singleSigner;
    return signer?.signer == SignerEntity.local &&
        isStandardSingleSignatureWallet;
  }

  bool get supportsLegacySend => isLiquid
      ? !isWatchOnly
      : isStandardLocalSingleSignatureWallet ||
            (signsRemotely && isStandardSingleSignatureWallet);

  bool get supportsSend =>
      isLiquid ? !isWatchOnly : hasLocalSigner || hasRemoteSigner;

  bool get signsRemotely => hasRemoteSigner;
  bool get isHardwareWallet => signerDevice != null;
  bool get isBitcoinHardwareWallet => isBitcoin && isHardwareWallet;
  bool get hasLocalSigner =>
      signers.any((signer) => signer.signer == SignerEntity.local);
  bool get hasRemoteSigner =>
      signers.any((signer) => signer.signer == SignerEntity.remote);
}

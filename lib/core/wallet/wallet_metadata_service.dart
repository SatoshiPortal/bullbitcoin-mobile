import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/descriptor_derivation.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';

class WalletMetadataService {
  static String encodeOrigin({
    required String fingerprint,
    required Network network,
    required ScriptType scriptType,
  }) {
    String networkPath;
    if (network.isBitcoin && network.isMainnet) {
      networkPath = "0h";
    } else if (network.isLiquid && network.isMainnet) {
      networkPath = "1776h";
    } else if (network.isTestnet) {
      networkPath = "1h";
    } else {
      throw 'Unexpected network path';
    }

    String prefixFormat = '';
    String scriptPath = '';
    switch (scriptType) {
      case ScriptType.bip84:
        prefixFormat = network.isBitcoin ? 'wpkh([*])' : 'elwpkh([*])';
        scriptPath = '84h';
      case ScriptType.bip49:
        prefixFormat = network.isBitcoin ? 'sh(wpkh([*]))' : 'elsh(wpkh([*]))';
        scriptPath = '49h';
      case ScriptType.bip44:
        prefixFormat = network.isBitcoin ? 'pkh([*])' : 'elpkh([*])';
        scriptPath = '44h';
    }

    const String accountPath = '0h';
    final path = '[$fingerprint/$scriptPath/$networkPath/$accountPath]';
    return prefixFormat.replaceAll('[*]', path);
  }

  static ({
    String fingerprint,
    Network network,
    ScriptType script,
    String account,
  })
  decodeOrigin({required String origin}) {
    final match = RegExp(
      r'\[([a-fA-F0-9]+)/(\d+h)/(\d+h)/(\d+h)\]',
    ).firstMatch(origin);

    if (match == null) throw 'Invalid origin format: $origin';

    final fingerprint = match.group(1)!;
    final matchingScript = match.group(2)!;
    final matchingNetwork = match.group(3)!;
    final account = match.group(4)!;

    ScriptType script;
    switch (matchingScript) {
      case '84h':
        script = ScriptType.bip84;
      case '49h':
        script = ScriptType.bip49;
      case '44h':
        script = ScriptType.bip44;
      default:
        throw 'Unknown script: $matchingScript';
    }

    Network network;
    switch (matchingNetwork) {
      case '0h':
        network = Network.bitcoinMainnet;
      case '1h':
        if (origin.contains('elwpkh(') ||
            origin.contains('elsh(wpkh(') ||
            origin.contains('elpkh(')) {
          network = Network.liquidTestnet;
        } else {
          network = Network.bitcoinTestnet;
        }
      case '1776h':
        network = Network.liquidMainnet;

      default:
        throw 'Unknown script: $matchingNetwork';
    }

    return (
      fingerprint: fingerprint,
      network: network,
      script: script,
      account: account,
    );
  }

  static Future<WalletMetadataModel> deriveFromSeed({
    required Seed seed,
    required Network network,
    required ScriptType scriptType,
    String? label,
    required bool isDefault,
  }) async {
    final xpub = await Bip32Derivation.getAccountXpub(
      seedBytes: seed.bytes,
      network: network,
      scriptType: scriptType,
    );

    String descriptor;
    String changeDescriptor;
    if (network.isBitcoin) {
      final xprv = Bip32Derivation.getXprvFromSeed(seed.bytes, network);
      descriptor =
          await DescriptorDerivation.derivePublicBitcoinDescriptorFromXpriv(
            xprv,
            scriptType: scriptType,
            isTestnet: network.isTestnet,
          );
      changeDescriptor =
          await DescriptorDerivation.derivePublicBitcoinDescriptorFromXpriv(
            xprv,
            scriptType: scriptType,
            isTestnet: network.isTestnet,
            isInternalKeychain: true,
          );
    } else {
      if (seed is! MnemonicSeed) {
        throw MnemonicSeedNeededException(
          'Mnemonic seed is required for Liquid network',
        );
      }

      descriptor =
          await DescriptorDerivation.derivePublicLiquidDescriptorFromMnemonic(
            seed.mnemonicWords.join(' '),
            scriptType: scriptType,
            isTestnet: network.isTestnet,
          );
      changeDescriptor = descriptor;
    }

    return WalletMetadataModel(
      id: encodeOrigin(
        fingerprint: seed.masterFingerprint,
        network: network,
        scriptType: scriptType,
      ),
      masterFingerprint: seed.masterFingerprint,
      xpubFingerprint: xpub.fingerprintHex,
      signer: Signer.local,
      signerDevice: null,
      xpub: xpub.convert(scriptType.getXpubType(network)),
      externalPublicDescriptor: descriptor,
      internalPublicDescriptor: changeDescriptor,
      isDefault: isDefault,
      label: label,
      isPhysicalBackupTested: false,
      isEncryptedVaultTested: false,
    );
  }

  static Future<WalletMetadataModel> deriveFromXpub({
    required String xpub,
    required Network network,
    required ScriptType scriptType,
    String label = '',
  }) async {
    if (network.isLiquid) {
      throw UnimplementedError(
        'Importing xpubs for Liquid network is not supported',
      );
    }

    final bip32Xpub = Bip32Derivation.getBip32Xpub(xpub);
    final xpubBase58 = bip32Xpub.toBase58();
    final pubkeyFingerprint = bip32Xpub.fingerprintHex;

    final descriptor =
        await DescriptorDerivation.deriveBitcoinDescriptorFromXpub(
          xpubBase58,
          fingerprint: pubkeyFingerprint,
          scriptType: scriptType,
          isTestnet: network.isTestnet,
        );
    final changeDescriptor =
        await DescriptorDerivation.deriveBitcoinDescriptorFromXpub(
          xpubBase58,
          fingerprint: pubkeyFingerprint,
          scriptType: scriptType,
          isTestnet: network.isTestnet,
          isInternalKeychain: true,
        );

    return WalletMetadataModel(
      id: WalletMetadataService.encodeOrigin(
        fingerprint: pubkeyFingerprint,
        network: network,
        scriptType: scriptType,
      ),
      xpubFingerprint: bip32Xpub.fingerprintHex,
      signer: Signer.none,
      signerDevice: null,
      xpub: bip32Xpub.convert(scriptType.getXpubType(network)),
      externalPublicDescriptor: descriptor,
      internalPublicDescriptor: changeDescriptor,
      label: label,
      masterFingerprint: '',
      isEncryptedVaultTested: false,
      isPhysicalBackupTested: false,
      isDefault: false,
    );
  }

  static Future<WalletMetadataModel> fromDescriptor(
    WatchOnlyDescriptorEntity entity,
  ) async {
    return WalletMetadataModel(
      id: WalletMetadataService.encodeOrigin(
        fingerprint: entity.masterFingerprint,
        network: entity.network,
        scriptType: entity.scriptType,
      ),
      masterFingerprint: entity.masterFingerprint,
      xpubFingerprint: entity.pubkeyFingerprint,
      signer: Signer.fromEntity(entity.signer),
      signerDevice:
          entity.signerDevice != null
              ? SignerDevice.fromEntity(entity.signerDevice!)
              : null,
      xpub: entity.pubkey,
      externalPublicDescriptor: entity.descriptor.external,
      internalPublicDescriptor: entity.descriptor.internal,
      isDefault: false,
      isEncryptedVaultTested: false,
      isPhysicalBackupTested: false,
      label: entity.label,
    );
  }
}

class MnemonicSeedNeededException implements Exception {
  final String message;

  MnemonicSeedNeededException(this.message);
}

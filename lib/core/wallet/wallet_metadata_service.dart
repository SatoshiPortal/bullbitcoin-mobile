import 'dart:convert';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/descriptor_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class WalletMetadataService {
  static String encodeOrigin({
    required String fingerprint,
    required bool isBitcoin,
    required bool isMainnet,
    required bool isTestnet,
    required bool isLiquid,
    required ScriptType scriptType,
  }) {
    String networkPath;
    if (isBitcoin && isMainnet) {
      networkPath = "0h";
    } else if (isBitcoin && isTestnet) {
      networkPath = "1h";
    } else if (isLiquid && isMainnet) {
      networkPath = "1667h";
    } else if (isLiquid && isTestnet) {
      networkPath = "1668h";
    } else {
      throw '';
    }

    String prefixFormat = '';
    String scriptPath = '';
    switch (scriptType) {
      case ScriptType.bip84:
        prefixFormat = isBitcoin ? 'wpkh([*])' : 'elwpkh([*])';
        scriptPath = '84h';
      case ScriptType.bip49:
        prefixFormat = isBitcoin ? 'sh(wpkh([*]))' : 'elsh(wpkh([*]))';
        scriptPath = '49h';
      case ScriptType.bip44:
        prefixFormat = isBitcoin ? 'pkh([*])' : 'elpkh([*])';
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
    final list = json.decode(origin) as List<String>;

    ScriptType script;
    switch (list[1]) {
      case '84h':
        script = ScriptType.bip84;
      case '49h':
        script = ScriptType.bip49;
      case '44h':
        script = ScriptType.bip44;
      default:
        throw 'Unknown script: ${list[1]}';
    }

    Network network;
    switch (list[2]) {
      case '0h':
        network = Network.bitcoinMainnet;
      case '1h':
        network = Network.bitcoinTestnet;
      case '1667h':
        network = Network.liquidMainnet;
      case '1668h':
        network = Network.liquidTestnet;
      default:
        throw 'Unknown script: ${list[2]}';
    }

    return (
      fingerprint: list.first,
      network: network,
      script: script,
      account: list.last,
    );
  }

  static Future<WalletMetadataModel> deriveFromSeed({
    required Seed seed,
    required Network network,
    required ScriptType scriptType,
    required String label,
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
        isBitcoin: network.isBitcoin,
        isMainnet: network.isMainnet,
        isTestnet: network.isTestnet,
        isLiquid: network.isLiquid,
        scriptType: scriptType,
      ),
      masterFingerprint: seed.masterFingerprint,
      xpubFingerprint: xpub.fingerprintHex,
      source: WalletSource.mnemonic.name,
      isBitcoin: network.isBitcoin,
      isLiquid: network.isLiquid,
      isMainnet: network.isMainnet,
      isTestnet: network.isTestnet,
      scriptType: scriptType.name,
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
    final fingerprint = bip32Xpub.fingerprintHex;

    final descriptor =
        await DescriptorDerivation.deriveBitcoinDescriptorFromXpub(
          xpubBase58,
          fingerprint: fingerprint,
          scriptType: scriptType,
          isTestnet: network.isTestnet,
        );
    final changeDescriptor =
        await DescriptorDerivation.deriveBitcoinDescriptorFromXpub(
          xpubBase58,
          fingerprint: fingerprint,
          scriptType: scriptType,
          isTestnet: network.isTestnet,
          isInternalKeychain: true,
        );

    return WalletMetadataModel(
      id: WalletMetadataService.encodeOrigin(
        fingerprint: fingerprint,
        isBitcoin: network.isBitcoin,
        isMainnet: network.isMainnet,
        isTestnet: network.isTestnet,
        isLiquid: network.isLiquid,
        scriptType: scriptType,
      ),
      xpubFingerprint: fingerprint,
      source: WalletSource.xpub.name,
      isBitcoin: network.isBitcoin,
      isLiquid: network.isLiquid,
      isMainnet: network.isMainnet,
      isTestnet: network.isTestnet,
      scriptType: scriptType.name,
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
}

class MnemonicSeedNeededException implements Exception {
  final String message;

  MnemonicSeedNeededException(this.message);
}

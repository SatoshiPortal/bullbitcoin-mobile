import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/bip32_derivation.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/entities/new_seed_entity.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/entities/new_wallet_metadata_entity.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/models/new_wallet_metadata_model.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/new_descriptor_derivation.dart';
import 'package:bb_mobile/core/storage/tables/v5_migrate_wallet_metadata_table.dart';

class NewWalletMetadataService {
  static String encodeOrigin({
    required String fingerprint,
    required NewNetwork network,
    required NewScriptType scriptType,
  }) {
    String networkPath;
    if (network.isBitcoin && network.isMainnet) {
      networkPath = "0h";
    } else if (network.isBitcoin && network.isTestnet) {
      networkPath = "1h";
    } else if (network.isLiquid && network.isMainnet) {
      networkPath = "1667h";
    } else if (network.isLiquid && network.isTestnet) {
      networkPath = "1668h";
    } else {
      throw 'Unexpected network path';
    }

    String prefixFormat = '';
    String scriptPath = '';
    switch (scriptType) {
      case NewScriptType.bip84:
        prefixFormat = network.isBitcoin ? 'wpkh([*])' : 'elwpkh([*])';
        scriptPath = '84h';
      case NewScriptType.bip49:
        prefixFormat = network.isBitcoin ? 'sh(wpkh([*]))' : 'elsh(wpkh([*]))';
        scriptPath = '49h';
      case NewScriptType.bip44:
        prefixFormat = network.isBitcoin ? 'pkh([*])' : 'elpkh([*])';
        scriptPath = '44h';
    }

    const String accountPath = '0h';
    final path = '[$fingerprint/$scriptPath/$networkPath/$accountPath]';
    return prefixFormat.replaceAll('[*]', path);
  }

  static ({
    String fingerprint,
    NewNetwork network,
    NewScriptType script,
    String account,
  })
  decodeOrigin({required String origin}) {
    final match = RegExp(
      r'\[([a-fA-F0-9]+)/(\d+h)/(\d+h)/(\d+h)\]',
    ).firstMatch(origin);

    if (match == null) {
      throw 'Invalid origin format: $origin';
    }

    final fingerprint = match.group(1)!;
    final matchingScript = match.group(2)!;
    final matchingNetwork = match.group(3)!;
    final account = match.group(4)!;

    NewScriptType script;
    switch (matchingScript) {
      case '84h':
        script = NewScriptType.bip84;
      case '49h':
        script = NewScriptType.bip49;
      case '44h':
        script = NewScriptType.bip44;
      default:
        throw 'Unknown script: $matchingScript';
    }

    NewNetwork network;
    switch (matchingNetwork) {
      case '0h':
        network = NewNetwork.bitcoinMainnet;
      case '1h':
        network = NewNetwork.bitcoinTestnet;
      case '1667h':
        network = NewNetwork.liquidMainnet;
      case '1668h':
        network = NewNetwork.liquidTestnet;
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

  static Future<NewWalletMetadataModel> deriveFromSeed({
    required NewSeedEntity seed,
    required NewNetwork network,
    required NewScriptType scriptType,
    required String label,
    required bool isDefault,
  }) async {
    final xpub = await NewBip32Derivation.getAccountXpub(
      seedBytes: seed.bytes,
      network: network,
      scriptType: scriptType,
    );

    String descriptor;
    String changeDescriptor;
    if (network.isBitcoin) {
      final xprv = NewBip32Derivation.getXprvFromSeed(seed.bytes, network);
      descriptor =
          await NewDescriptorDerivation.derivePublicBitcoinDescriptorFromXpriv(
            xprv,
            scriptType: scriptType,
            isTestnet: network.isTestnet,
          );
      changeDescriptor =
          await NewDescriptorDerivation.derivePublicBitcoinDescriptorFromXpriv(
            xprv,
            scriptType: scriptType,
            isTestnet: network.isTestnet,
            isInternalKeychain: true,
          );
    } else {
      if (seed is! NewMnemonicSeed) {
        throw NewMnemonicSeedNeededException(
          'Mnemonic seed is required for Liquid network',
        );
      }

      descriptor =
          await NewDescriptorDerivation.derivePublicLiquidDescriptorFromMnemonic(
            seed.mnemonicWords.join(' '),
            scriptType: scriptType,
            isTestnet: network.isTestnet,
          );
      changeDescriptor = descriptor;
    }

    return NewWalletMetadataModel(
      id: encodeOrigin(
        fingerprint: seed.masterFingerprint,
        network: network,
        scriptType: scriptType,
      ),
      masterFingerprint: seed.masterFingerprint,
      xpubFingerprint: xpub.fingerprintHex,
      source: NewWalletSource.mnemonic,
      xpub: xpub.convert(scriptType.getXpubType(network)),
      externalPublicDescriptor: descriptor,
      internalPublicDescriptor: changeDescriptor,
      isDefault: isDefault,
      label: label,
      isPhysicalBackupTested: false,
      isEncryptedVaultTested: false,
    );
  }

  static Future<NewWalletMetadataModel> deriveFromXpub({
    required String xpub,
    required NewNetwork network,
    required NewScriptType scriptType,
    String label = '',
  }) async {
    if (network.isLiquid) {
      throw UnimplementedError(
        'Importing xpubs for Liquid network is not supported',
      );
    }

    final bip32Xpub = NewBip32Derivation.getBip32Xpub(xpub);
    final xpubBase58 = bip32Xpub.toBase58();
    final fingerprint = bip32Xpub.fingerprintHex;

    final descriptor =
        await NewDescriptorDerivation.deriveBitcoinDescriptorFromXpub(
          xpubBase58,
          fingerprint: fingerprint,
          scriptType: scriptType,
          isTestnet: network.isTestnet,
        );
    final changeDescriptor =
        await NewDescriptorDerivation.deriveBitcoinDescriptorFromXpub(
          xpubBase58,
          fingerprint: fingerprint,
          scriptType: scriptType,
          isTestnet: network.isTestnet,
          isInternalKeychain: true,
        );

    return NewWalletMetadataModel(
      id: NewWalletMetadataService.encodeOrigin(
        fingerprint: fingerprint,
        network: network,
        scriptType: scriptType,
      ),
      xpubFingerprint: fingerprint,
      source: NewWalletSource.xpub,
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

class NewMnemonicSeedNeededException implements Exception {
  final String message;

  NewMnemonicSeedNeededException(this.message);
}

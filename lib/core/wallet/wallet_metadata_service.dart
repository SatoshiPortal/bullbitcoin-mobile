import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/descriptor_derivation.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_descriptor_key_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_signer_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

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
      r"\[([a-fA-F0-9]+)/(\d+)[h']/(\d+)[h']/(\d+)[h']\]",
    ).firstMatch(origin);

    if (match == null) throw 'Invalid origin format: $origin';

    final fingerprint = match.group(1)!;
    final matchingScript = match.group(2)!;
    final matchingNetwork = match.group(3)!;
    final account = '${match.group(4)}h';

    ScriptType script;
    switch (matchingScript) {
      case '84':
        script = ScriptType.bip84;
      case '49':
        script = ScriptType.bip49;
      case '44':
        script = ScriptType.bip44;
      default:
        throw 'Unknown script: $matchingScript';
    }

    Network network;
    switch (matchingNetwork) {
      case '0':
        network = Network.bitcoinMainnet;
      case '1':
        if (origin.contains('elwpkh(') ||
            origin.contains('elsh(wpkh(') ||
            origin.contains('elpkh(')) {
          network = Network.liquidTestnet;
        } else {
          network = Network.bitcoinTestnet;
        }
      case '1776':
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
    DateTime? birthday,
  }) async {
    final xpub = await Bip32Derivation.getAccountXpub(
      seedBytes: seed.bytes,
      network: network,
      scriptType: scriptType,
    );

    final String descriptor;
    if (network.isBitcoin) {
      descriptor =
          DescriptorDerivation.derivePublicBitcoinMultipathDescriptorFromXpub(
            xpub.toBase58(),
            scriptType: scriptType,
            isTestnet: network.isTestnet,
            masterFingerprint: seed.masterFingerprint,
            derivationPath: _accountDerivationPath(
              network: network,
              scriptType: scriptType,
            ),
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
    }

    return WalletMetadataModel(
      id: encodeOrigin(
        fingerprint: seed.masterFingerprint,
        network: network,
        scriptType: scriptType,
      ),
      network: network,
      signers: [
        WalletSignerModel(
          id: 'signer-0',
          signer: Signer.local,
          signerDevice: null,
          descriptorKeys: [
            WalletDescriptorKeyModel(
              id: 'key-0',
              signerId: 'signer-0',
              masterFingerprint: seed.masterFingerprint,
              xpubFingerprint: xpub.fingerprintHex,
              xpub: xpub.convert(scriptType.getXpubType(network)),
              derivationPath: _accountDerivationPath(
                network: network,
                scriptType: scriptType,
              ),
              descriptorPath: network.isBitcoin
                  ? standardSingleSignatureDescriptorPath
                  : '',
            ),
          ],
        ),
      ],
      publicDescriptor: descriptor,
      isDefault: isDefault,
      label: label,
      isPhysicalBackupTested: false,
      isEncryptedVaultTested: false,
      birthday: birthday,
    );
  }

  static String _accountDerivationPath({
    required Network network,
    required ScriptType scriptType,
  }) => "m/${scriptType.purpose}'/${network.coinType}'/0'";
}

class MnemonicSeedNeededException extends BullException {
  MnemonicSeedNeededException(super.message);
}

import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/descriptor_derivation.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/network_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bull_logger/bull_logger.dart';
import 'package:secrets/secrets.dart';

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

  /// Builds a wallet's metadata from a stored secret.
  ///
  /// Every derivation happens inside the `secrets` package: what comes
  /// back is an xpub and public descriptors. The seed, the master xprv
  /// and the BIP39 words never reach this method.
  static Future<WalletMetadataModel> deriveFromSecret({
    required Secret secret,
    required Network network,
    required ScriptType scriptType,
    String? label,
    required bool isDefault,
    DateTime? birthday,
  }) async {
    // Each chain with its own SLIP-44 coin type — 0/1 for Bitcoin, 1776/1 for Liquid — as every wallet already on a device was derived. Folding Liquid onto Bitcoin mainnet changed `xpub` and `xpubFingerprint` for every Liquid wallet.
    final xpub = _unwrap(
      network.isBitcoin
          ? await secret.derive.xpub(
              network: network.bitcoin,
              scriptType: scriptType.shared,
            )
          : await secret.derive.liquidXpub(
              network: network.liquid,
              scriptType: scriptType.shared,
            ),
    );

    final String descriptor;
    final String changeDescriptor;
    if (network.isBitcoin) {
      final descriptors = _unwrap(
        await secret.derive.descriptors.bitcoin(
          network: network.bitcoin,
          scriptType: scriptType.shared,
        ),
      );
      descriptor = descriptors.external;
      changeDescriptor = descriptors.internal;
    } else {
      // The confidential descriptor covers both keychains, and a
      // seed-only secret is refused before anything is loaded.
      final scope = _unwrap(
        await secret.derive.descriptors.liquid(network: network.liquid),
      );
      switch (scope) {
        case WholeSecret(:final value):
          descriptor = value;
        case WordsOnly(:final value):
          // lwk takes no passphrase, so this wallet is the passphrase-less
          // sibling's: same addresses, same funds. Recorded because the
          // metadata says the wallet derives from a passphrase secret and
          // the Liquid half of it does not.
          log.warning(
            'LIQUID_WORDS_ONLY: Liquid wallet for ${secret.info.id.hex} '
            'derives from the words alone; its passphrase takes no part',
          );
          descriptor = value;
      }
      changeDescriptor = descriptor;
    }

    final fingerprint = secret.info.id.hex;
    return WalletMetadataModel(
      id: encodeOrigin(
        fingerprint: fingerprint,
        network: network,
        scriptType: scriptType,
      ),
      masterFingerprint: fingerprint,
      // Public math on a public key: deriving an xpub's own fingerprint
      // needs nothing from the secret.
      xpubFingerprint: Bip32Derivation.getBip32Xpub(xpub).fingerprintHex,
      signer: Signer.local,
      signerDevice: null,
      xpub: xpub,
      externalPublicDescriptor: descriptor,
      internalPublicDescriptor: changeDescriptor,
      isDefault: isDefault,
      label: label,
      isPhysicalBackupTested: false,
      isEncryptedVaultTested: false,
      birthday: birthday,
    );
  }

  /// Turns a secrets failure into the exception this service has always
  /// thrown, so callers keep their existing error handling.
  static T _unwrap<T>(Result<T, SecretFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw MnemonicSeedNeededException(
      failure.toString(),
    ),
  };

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
      signerDevice: entity.signerDevice != null
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

class MnemonicSeedNeededException extends BullException {
  MnemonicSeedNeededException(super.message);
}

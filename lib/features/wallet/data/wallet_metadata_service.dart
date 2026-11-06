import 'package:bb_mobile/features/wallet/data/wallet_network_codec.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/descriptor_derivation.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:secrets/secrets.dart';

class WalletMetadataService {
  static String encodeOrigin({
    required String fingerprint,
    required Network network,
    required ScriptType scriptType,
  }) {
    final networkPath = switch (network) {
      Network.bitcoinMainnet => '0h',
      Network.liquidMainnet => '1776h',
      Network.bitcoinTestnet ||
      Network.bitcoinRegtest ||
      Network.liquidTestnet ||
      Network.liquidRegtest => '1h',
    };

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

    if (match == null) throw 'Invalid origin format';

    final fingerprint = match.group(1);
    final matchingScript = match.group(2);
    final matchingNetwork = match.group(3);
    final account = match.group(4);
    if (fingerprint == null ||
        matchingScript == null ||
        matchingNetwork == null ||
        account == null) {
      throw 'Invalid origin format';
    }

    final script = switch (matchingScript) {
      '84h' => ScriptType.bip84,
      '49h' => ScriptType.bip49,
      '44h' => ScriptType.bip44,
      _ => throw 'Unknown origin script',
    };

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
        throw 'Unknown origin network';
    }

    return (
      fingerprint: fingerprint,
      network: network,
      script: script,
      account: account,
    );
  }

  /// Rebuilds the historical default-account origin used by BIP329 without
  /// interpreting its coin type as an active wallet network. Coin type 1
  /// deliberately remains unattributed between testnet and regtest here.
  static String canonicalBip329Origin(String keyOrigin) {
    final derivation = parseOrigin(origin: keyOrigin);
    final coinType = RegExp(
      r'\[[a-fA-F0-9]+/\d+h/(\d+h)/\d+h\]',
    ).firstMatch(keyOrigin)?.group(1);
    if (coinType != '0h' && coinType != '1h' && coinType != '1776h') {
      throw const FormatException('Unsupported derivation coin type');
    }
    final prefix = coinType == '1776h' ? 'el' : '';
    final path =
        '[${derivation.fingerprint}/${derivation.script.purpose}h/$coinType/0h]';
    return switch (derivation.script) {
      ScriptType.bip84 => '${prefix}wpkh($path)',
      ScriptType.bip49 => '${prefix}sh(wpkh($path))',
      ScriptType.bip44 => '${prefix}pkh($path)',
    };
  }

  static const regtestSuffix = ':regtest';

  /// The derivation origin stays suitable for BIP329 on every network.
  static String originFromId(String id) => id.endsWith(regtestSuffix)
      ? id.substring(0, id.length - regtestSuffix.length)
      : id;

  static String encodeId({
    required String fingerprint,
    required Network network,
    required ScriptType scriptType,
  }) {
    final origin = encodeOrigin(
      fingerprint: fingerprint,
      network: network,
      scriptType: scriptType,
    );
    return switch (network) {
      Network.bitcoinRegtest ||
      Network.liquidRegtest => '$origin$regtestSuffix',
      _ => origin,
    };
  }

  /// Parses derivation metadata without treating its coin type as a network.
  static ({String fingerprint, ScriptType script, String account}) parseOrigin({
    required String origin,
  }) {
    final match = RegExp(
      r'\[([a-fA-F0-9]+)/(\d+h)/(\d+h)/(\d+h)\]',
    ).firstMatch(origin);
    final fingerprint = match?.group(1);
    final purpose = match?.group(2);
    final account = match?.group(4);
    if (fingerprint == null || purpose == null || account == null) {
      throw 'Invalid origin format';
    }
    final script = switch (purpose) {
      '84h' => ScriptType.bip84,
      '49h' => ScriptType.bip49,
      '44h' => ScriptType.bip44,
      _ => throw 'Unknown origin script',
    };
    return (fingerprint: fingerprint, script: script, account: account);
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
      await secret.derive.xpub(
        network: network.shared,
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
      // Liquid descriptors ignore the passphrase, consistently with signing.
      descriptor = _unwrap(
        await secret.derive.descriptors.liquid(network: network.liquid),
      );
      changeDescriptor = descriptor;
    }

    final fingerprint = secret.info.id.hex;
    return WalletMetadataModel(
      networkCode: WalletNetworkCodec.encode(network),
      id: encodeId(
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
    // Descriptor keys use BIP32 versions for the target network, even when
    // the imported account uses SLIP132 (ypub/zpub/upub/vpub) versions.
    final xpubBase58 = bip32Xpub.convert(
      network.isMainnet ? XpubType.xpub : XpubType.tpub,
    );
    final pubkeyFingerprint = bip32Xpub.fingerprintHex;

    final descriptor =
        await DescriptorDerivation.deriveBitcoinDescriptorFromXpub(
          xpubBase58,
          fingerprint: pubkeyFingerprint,
          scriptType: scriptType,
          isTestnet: switch (network) {
            Network.bitcoinMainnet => false,
            Network.bitcoinTestnet || Network.bitcoinRegtest => true,
            _ => throw const FormatException('Unsupported xpub network'),
          },
        );
    final changeDescriptor =
        await DescriptorDerivation.deriveBitcoinDescriptorFromXpub(
          xpubBase58,
          fingerprint: pubkeyFingerprint,
          scriptType: scriptType,
          isTestnet: switch (network) {
            Network.bitcoinMainnet => false,
            Network.bitcoinTestnet || Network.bitcoinRegtest => true,
            _ => throw const FormatException('Unsupported xpub network'),
          },
          isInternalKeychain: true,
        );

    return WalletMetadataModel(
      networkCode: WalletNetworkCodec.encode(network),
      id: WalletMetadataService.encodeId(
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
      networkCode: WalletNetworkCodec.encode(entity.network),
      id: WalletMetadataService.encodeId(
        fingerprint: entity.masterFingerprint,
        network: entity.network,
        scriptType: entity.scriptType,
      ),
      masterFingerprint: entity.masterFingerprint,
      xpubFingerprint: entity.pubkeyFingerprint,
      signer: Signer.fromEntity(entity.signer),
      signerDevice: switch (entity.signerDevice) {
        final device? => SignerDevice.fromEntity(device),
        null => null,
      },
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

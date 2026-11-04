import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bs58check/bs58check.dart' as base58;
import 'package:primitives/primitives.dart' as primitives;

import 'descriptor_derivation.dart';
import '../../domain/wallet.dart';
import '../../domain/wallet_metadata.dart';
import '../../domain/wallet_origin_codec.dart';
import '../../domain/signer_entity.dart';

/// Derives watch-only metadata without exposing native keys or descriptors.
final class WalletXpubImport {
  static Future<WalletMetadata> derive({
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

    final bip32Xpub = _parse(xpub);
    final xpubBase58 = bip32Xpub.toBase58();
    final pubkeyFingerprint = bip32Xpub.fingerprint
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

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

    return WalletMetadata(
      id: WalletOriginCodec.encodeOrigin(
        fingerprint: pubkeyFingerprint,
        network: network,
        scriptType: scriptType,
      ),
      xpubFingerprint: bip32Xpub.fingerprint
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(),
      signer: SignerEntity.none,
      signerDevice: null,
      xpub: _convert(bip32Xpub, scriptType, network),
      externalPublicDescriptor: descriptor,
      internalPublicDescriptor: changeDescriptor,
      label: label,
      masterFingerprint: '',
      isEncryptedVaultTested: false,
      isPhysicalBackupTested: false,
      isDefault: false,
    );
  }

  static bip32.Bip32Keys _parse(String xpub) {
    final decoded = base58.decode(xpub);
    final keyBytes = decoded.sublist(4);
    final xpubBytes = Uint8List.fromList([
      ...primitives.XpubType.xpub.versionBytes,
      ...keyBytes,
    ]);
    return bip32.Bip32Keys.fromBase58(base58.encode(xpubBytes));
  }

  static String _convert(
    bip32.Bip32Keys key,
    ScriptType scriptType,
    Network network,
  ) {
    final target = switch ((network.isMainnet, scriptType)) {
      (true, ScriptType.bip44) => primitives.XpubType.xpub,
      (true, ScriptType.bip49) => primitives.XpubType.ypub,
      (true, ScriptType.bip84) => primitives.XpubType.zpub,
      (false, ScriptType.bip44) => primitives.XpubType.tpub,
      (false, ScriptType.bip49) => primitives.XpubType.upub,
      (false, ScriptType.bip84) => primitives.XpubType.vpub,
    };
    final decoded = base58.decode(key.toBase58());
    return base58.encode(
      Uint8List.fromList([...target.versionBytes, ...decoded.sublist(4)]),
    );
  }
}

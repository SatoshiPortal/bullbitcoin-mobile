import 'dart:typed_data';

import 'package:bb_mobile/core/domain/entities/seed.dart';
import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/core/domain/services/wallet_repository_manager.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:bip32/bip32.dart' as bip32;
import 'package:bs58check/bs58check.dart' as base58;
import 'package:lwk/lwk.dart' as lwk;

/// Enum to represent different extended public key formats
enum XpubType {
  xpub([0x04, 0x88, 0xB2, 0x1E]), // Mainnet Legacy P2PKH
  ypub([0x04, 0x9D, 0x7C, 0xB2]), // Mainnet Nested SegWit (BIP49)
  zpub([0x04, 0xB2, 0x47, 0x46]), // Mainnet Native SegWit (BIP84)
  tpub([0x04, 0x35, 0x87, 0xCF]), // Testnet Legacy P2PKH
  upub([0x04, 0x4A, 0x52, 0x62]), // Testnet Nested SegWit (BIP49)
  vpub(
    [0x04, 0x5F, 0x1C, 0xF6],
  ); // Testnet Native SegWit (BIP84)

  final List<int> versionBytes;
  const XpubType(this.versionBytes);
}

extension ScriptTypeX on ScriptType {
  XpubType getXpubType(Network network) {
    if (network.isMainnet) {
      switch (this) {
        case ScriptType.bip44:
          return XpubType.xpub;
        case ScriptType.bip49:
          return XpubType.ypub;
        case ScriptType.bip84:
          return XpubType.zpub;
      }
    } else {
      switch (this) {
        case ScriptType.bip44:
          return XpubType.tpub;
        case ScriptType.bip49:
          return XpubType.upub;
        case ScriptType.bip84:
          return XpubType.vpub;
      }
    }
  }
}

abstract class WalletMetadataDerivationService {
  Future<WalletMetadata> fromSeed({
    required Seed seed,
    required Network network,
    required ScriptType scriptType,
    String label,
  });
}

class WalletMetadataDerivationServiceImpl
    implements WalletMetadataDerivationService {
  const WalletMetadataDerivationServiceImpl();

  @override
  Future<WalletMetadata> fromSeed({
    required Seed seed,
    required Network network,
    required ScriptType scriptType,
    String label = '',
  }) async {
    final xpub = await _getAccountXpub(
      seed,
      network: network,
      scriptType: scriptType,
    );

    final descriptor = await _derivePublicDescriptor(
      seed,
      network: network,
      scriptType: scriptType,
    );
    final changeDescriptor = network.isLiquid
        ? descriptor
        : await _derivePublicChangeDescriptor(
            seed,
            network: network,
            scriptType: scriptType,
          );

    return WalletMetadata(
      masterFingerprint: seed.masterFingerprint,
      xpubFingerprint: xpub.fingerprintHex,
      source: WalletSource.mnemonic,
      network: network,
      scriptType: scriptType,
      xpub: xpub.convert(scriptType.getXpubType(network)),
      externalPublicDescriptor: descriptor,
      internalPublicDescriptor: changeDescriptor,
      isDefault: true,
      label: label,
    );
  }

  Future<bip32.BIP32> _getAccountXpub(
    Seed seed, {
    required ScriptType scriptType,
    Network network = Network.bitcoinMainnet,
    int accountIndex = 0,
  }) async {
    final root = bip32.BIP32.fromSeed(seed.seedBytes);
    final derivationPath =
        "m/${scriptType.purpose}'/${network.coinType}'/$accountIndex'";
    final derivedAccountKey = root.derivePath(derivationPath);
    final xpub = derivedAccountKey.neutered();

    return xpub;
  }

  Future<String> _derivePublicDescriptor(
    Seed seed, {
    required ScriptType scriptType,
    Network network = Network.bitcoinMainnet,
  }) async {
    if (network.isBitcoin) {
      final xprv = _getXprvFromSeed(seed);
      final secretKey = await bdk.DescriptorSecretKey.fromString(xprv);
      final bdkNetwork = network.bdkNetwork;
      bdk.Descriptor descriptor;

      switch (scriptType) {
        case ScriptType.bip84:
          descriptor = await bdk.Descriptor.newBip84(
            secretKey: secretKey,
            network: bdkNetwork,
            keychain: bdk.KeychainKind.externalChain,
          );
        case ScriptType.bip49:
          descriptor = await bdk.Descriptor.newBip49(
            secretKey: secretKey,
            network: bdkNetwork,
            keychain: bdk.KeychainKind.externalChain,
          );
        case ScriptType.bip44:
          descriptor = await bdk.Descriptor.newBip44(
            secretKey: secretKey,
            network: bdkNetwork,
            keychain: bdk.KeychainKind.externalChain,
          );
      }

      return descriptor.asString();
    } else {
      if (seed is! MnemonicSeed) {
        throw Exception(
          'Liquid confidential descriptor requires a mnemonic seed',
        );
      }

      final mnemonic = seed.mnemonicWords.join(' ');
      final lwkNetwork = network.lwkNetwork;

      final lwk.Descriptor confidentialDescriptor =
          await lwk.Descriptor.newConfidential(
        network: lwkNetwork,
        mnemonic: mnemonic,
      );

      return confidentialDescriptor.ctDescriptor;
    }
  }

  Future<String> _derivePublicChangeDescriptor(
    Seed seed, {
    required ScriptType scriptType,
    Network network = Network.bitcoinMainnet,
  }) async {
    final xprv = _getXprvFromSeed(seed);
    final secretKey = await bdk.DescriptorSecretKey.fromString(xprv);

    if (network.isLiquid) {
      throw UnimplementedError(
        'No internal chain support in lwk for Liquid network',
      );
    }

    final bdkNetwork = network.bdkNetwork;
    bdk.Descriptor descriptor;

    switch (scriptType) {
      case ScriptType.bip84:
        descriptor = await bdk.Descriptor.newBip84(
          secretKey: secretKey,
          network: bdkNetwork,
          keychain: bdk.KeychainKind.internalChain,
        );
      case ScriptType.bip49:
        descriptor = await bdk.Descriptor.newBip49(
          secretKey: secretKey,
          network: bdkNetwork,
          keychain: bdk.KeychainKind.internalChain,
        );
      case ScriptType.bip44:
        descriptor = await bdk.Descriptor.newBip44(
          secretKey: secretKey,
          network: bdkNetwork,
          keychain: bdk.KeychainKind.internalChain,
        );
    }

    return descriptor.asString();
  }

  String _getXprvFromSeed(Seed seed) {
    final root = bip32.BIP32.fromSeed(seed.seedBytes);
    return root.toBase58();
  }
}

extension Bip32X on bip32.BIP32 {
  /// Get the fingerprint of the BIP32 key as a hex string
  String get fingerprintHex {
    final fingerprintBytes = fingerprint;
    return fingerprintBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Converts an xpub to different extended public key formats
  String convert(XpubType targetType) {
    final xpub = toBase58();
    final decoded = base58.decode(xpub);
    final versionBytes = Uint8List.fromList(targetType.versionBytes);
    final keyBytes = decoded.sublist(4); // Remove existing xpub version bytes
    final newBytes =
        Uint8List.fromList([...versionBytes, ...keyBytes]); // Apply new prefix
    return base58.encode(newBytes);
  }
}

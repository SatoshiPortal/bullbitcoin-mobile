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
    bool isDefault,
  });
  Future<WalletMetadata> fromXpub({
    required String xpub,
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
    bool isDefault = true,
  }) async {
    final xpub = await _getAccountXpub(
      seed,
      network: network,
      scriptType: scriptType,
    );

    final descriptor = await _derivePublicDescriptorFromSeed(
      seed,
      network: network,
      scriptType: scriptType,
    );
    final changeDescriptor = network.isLiquid
        ? descriptor
        : await _derivePublicDescriptorFromSeed(
            seed,
            network: network,
            scriptType: scriptType,
            isInternalKeychain: true,
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
      isDefault: isDefault,
      label: label,
    );
  }

  @override
  Future<WalletMetadata> fromXpub({
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

    final bip32Xpub = _getBip32Xpub(xpub);

    final descriptor = await _deriveDescriptorFromXpub(
      bip32Xpub,
      network: network,
      scriptType: scriptType,
    );
    final changeDescriptor = await _deriveDescriptorFromXpub(
      bip32Xpub,
      network: network,
      scriptType: scriptType,
      isInternalKeychain: true,
    );

    return WalletMetadata(
      xpubFingerprint: bip32Xpub.fingerprintHex,
      source: WalletSource.xpub,
      network: network,
      scriptType: scriptType,
      xpub: bip32Xpub.convert(scriptType.getXpubType(network)),
      externalPublicDescriptor: descriptor,
      internalPublicDescriptor: changeDescriptor,
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

  Future<String> _derivePublicDescriptorFromSeed(
    Seed seed, {
    required ScriptType scriptType,
    required Network network,
    bool isInternalKeychain = false,
  }) async {
    // TODO: check if this check and throw are needed, since the descriptor returned by lwk includes both external and internal chains
    if (network.isLiquid && isInternalKeychain) {
      throw UnimplementedError(
        'No separate internal chain support in lwk for Liquid network.',
      );
    }

    if (network.isBitcoin) {
      final xprv = _getXprvFromSeed(seed, network);
      final secretKey = await bdk.DescriptorSecretKey.fromString(xprv);
      final bdkNetwork = network.bdkNetwork;
      final keychain = isInternalKeychain
          ? bdk.KeychainKind.internalChain
          : bdk.KeychainKind.externalChain;
      bdk.Descriptor descriptor;

      switch (scriptType) {
        case ScriptType.bip84:
          descriptor = await bdk.Descriptor.newBip84(
            secretKey: secretKey,
            network: bdkNetwork,
            keychain: keychain,
          );
        case ScriptType.bip49:
          descriptor = await bdk.Descriptor.newBip49(
            secretKey: secretKey,
            network: bdkNetwork,
            keychain: keychain,
          );
        case ScriptType.bip44:
          descriptor = await bdk.Descriptor.newBip44(
            secretKey: secretKey,
            network: bdkNetwork,
            keychain: keychain,
          );
      }

      // `asString` returns the public descriptor.
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

  Future<String> _deriveDescriptorFromXpub(
    bip32.BIP32 xpub, {
    required ScriptType scriptType,
    Network network = Network.bitcoinMainnet,
    bool isInternalKeychain = false,
  }) async {
    final publicKey = await bdk.DescriptorPublicKey.fromString(xpub.toBase58());
    final fingerPrint = xpub.fingerprintHex;
    final bdkNetwork = network.bdkNetwork;
    final keychain = isInternalKeychain
        ? bdk.KeychainKind.internalChain
        : bdk.KeychainKind.externalChain;

    bdk.Descriptor.newBip84Public(
      publicKey: publicKey,
      fingerPrint: fingerPrint,
      network: bdkNetwork,
      keychain: keychain,
    );
    bdk.Descriptor descriptor;

    switch (scriptType) {
      case ScriptType.bip84:
        descriptor = await bdk.Descriptor.newBip84Public(
          publicKey: publicKey,
          fingerPrint: fingerPrint,
          network: bdkNetwork,
          keychain: keychain,
        );
      case ScriptType.bip49:
        descriptor = await bdk.Descriptor.newBip49Public(
          publicKey: publicKey,
          fingerPrint: fingerPrint,
          network: bdkNetwork,
          keychain: keychain,
        );
      case ScriptType.bip44:
        descriptor = await bdk.Descriptor.newBip44Public(
          publicKey: publicKey,
          fingerPrint: fingerPrint,
          network: bdkNetwork,
          keychain: keychain,
        );
    }

    return descriptor.asString();
  }

  String _getXprvFromSeed(Seed seed, Network network) {
    final nw = network == Network.bitcoinTestnet
        ? bip32.NetworkType(
            wif: 0x80,
            bip32: bip32.Bip32Type(public: 0x043587CF, private: 0x04358394),
          )
        : null;
    final root = bip32.BIP32.fromSeed(seed.seedBytes, nw);
    return root.toBase58();
  }

  bip32.BIP32 _getBip32Xpub(String xpub) {
    final decoded = base58.decode(xpub);
    final keyBytes = decoded.sublist(4); // Remove xpub version bytes
    // Add xpub version bytes, since the bip32 library expects them like that
    final xpubBytes =
        Uint8List.fromList([...XpubType.xpub.versionBytes, ...keyBytes]);
    return bip32.BIP32.fromBase58(base58.encode(xpubBytes));
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

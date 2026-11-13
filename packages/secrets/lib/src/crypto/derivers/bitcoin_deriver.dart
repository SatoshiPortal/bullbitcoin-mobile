import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:secrets/src/crypto/derivers/fingerprint_deriver.dart';
import 'package:secrets/src/crypto/exceptions.dart';
import 'package:meta/meta.dart';

/// Public descriptors for both keychains of a wallet.
typedef Descriptors = ({String external, String internal});

/// Bitcoin derivations: the BIP32 root, account xpubs, bdk descriptors.
///
/// Works from the seed, so a bytes-only secret serves it. Reached as
/// `Deriver.bitcoin`.
final class BitcoinDeriver {
  @internal
  const BitcoinDeriver();

  /// The master xprv, encoded for [network].
  ///
  /// bip32_keys defaults to mainnet version bytes; the test environments
  /// need theirs spelled out or the xprv decodes as mainnet downstream.
  /// The collapse to two cases is BIP32's own: testnet, signet and
  /// regtest all encode as 0x043587CF/0x04358394 (SLIP-132), so a `tprv`
  /// on signet is correct, not an approximation.
  String masterXprv(SecretMaterial secret, BitcoinNetwork network) {
    final networkType = network.isMainnet
        ? null
        : bip32.NetworkType(
            // Testnet WIF. Never reaches `toBase58`, which encodes the
            // bip32 version bytes only, but a wrong constant is a wrong
            // constant.
            wif: 0xEF,
            bip32: bip32.Bip32Type(public: 0x043587CF, private: 0x04358394),
          );
    return bip32.Bip32Keys.fromSeed(
      secret.seedBytes,
      network: networkType,
    ).toBase58();
  }

  /// A public account key at the exact supplied origin path.
  PublicAccountKey account(
    SecretMaterial secret, {
    required String derivationPath,
    required BitcoinNetwork network,
    String? passphrase,
  }) {
    final path = normalizePath(derivationPath);
    final material = withPassphrase(secret, passphrase);
    final root = bip32.Bip32Keys.fromSeed(material.seedBytes);
    final xpub = root.derivePath(path).neutered.toBase58();
    return PublicAccountKey(
      fingerprint: const FingerprintDeriver().fingerprint(material.seedBytes),
      xpub: (network.isMainnet ? XpubType.xpub : XpubType.tpub).reencode(xpub),
      derivationPath: path,
    );
  }

  /// Applies an operation-only override after the stored secret was verified.
  SecretMaterial withPassphrase(SecretMaterial secret, String? passphrase) {
    if (passphrase == null) return secret;
    if (secret case Mnemonic(:final words, :final language)) {
      if (secret.passphrase == passphrase) return secret;
      final bytes = const FingerprintDeriver().seed(
        words,
        language: language,
        passphrase: passphrase,
      );
      return Mnemonic(
        id: const FingerprintDeriver().fingerprint(bytes),
        words: words,
        language: language,
        passphrase: passphrase,
        seedBytes: bytes,
      );
    }
    if (passphrase.isEmpty) return secret;
    throw const PassphraseUnsupported('A raw seed cannot use a passphrase');
  }

  /// Canonical BIP32 path, with hardened components written using apostrophes.
  String normalizePath(String path) {
    if (!RegExp(r"^m(?:/[0-9]+['h]?)*$").hasMatch(path)) {
      throw const FormatException('Invalid account derivation path');
    }
    final parts = <String>['m'];
    for (final component in path.split('/').skip(1)) {
      final hardened = component.endsWith("'") || component.endsWith('h');
      final index = int.tryParse(
        hardened ? component.substring(0, component.length - 1) : component,
      );
      if (index == null || index > 0x7fffffff) {
        throw const FormatException('Invalid account derivation index');
      }
      parts.add("$index${hardened ? "'" : ''}");
    }
    return parts.join('/');
  }

  /// Account-level extended public key, re-encoded to [xpubType].
  String xpub(
    SecretMaterial secret, {
    required ScriptType scriptType,
    required int coinType,
    required XpubType xpubType,
    int accountIndex = 0,
  }) {
    final root = bip32.Bip32Keys.fromSeed(secret.seedBytes);
    final path = "m/${scriptType.purpose}'/$coinType'/$accountIndex'";
    return xpubType.reencode(root.derivePath(path).neutered.toBase58());
  }

  /// External and internal public descriptors.
  ///
  /// Built from the master xprv, as the app always did. bdk's
  /// `NetworkKind` has only main and test — that is bdk's model, not a
  /// shortcut: descriptor version bytes are identical across testnet,
  /// signet and regtest.
  Future<Descriptors> descriptors(
    SecretMaterial secret, {
    required ScriptType scriptType,
    required BitcoinNetwork network,
    int accountIndex = 0,
  }) async {
    final secretKey = bdk.DescriptorSecretKey.fromString(
      privateKey: masterXprv(secret, network),
    );
    // Each bdk handle is freed as soon as its string is read: they are
    // UniFFI handles holding an xprv, and their finalizers would
    // otherwise keep one in native memory until the GC ran. See
    // `BitcoinSigner` for the full note.
    String build(bdk.KeychainKind keychain) {
      final descriptor = privateDescriptor(
        secretKey,
        scriptType: scriptType,
        network: network,
        accountIndex: accountIndex,
        keychain: keychain,
      );
      try {
        // `toString` returns the public descriptor.
        return descriptor.toString();
      } finally {
        descriptor.dispose();
      }
    }

    try {
      return (
        external: build(bdk.KeychainKind.external_),
        internal: build(bdk.KeychainKind.internal),
      );
    } finally {
      secretKey.dispose();
    }
  }

  /// Builds the same account path for public derivation and signing.
  ///
  /// BDK's BIP44/49/84 templates hardcode account zero. Parsing an explicit
  /// private descriptor supports any account while retaining its key origin
  /// when BDK converts it to a public descriptor. The caller owns the returned
  /// handle and must dispose it before returning from the operation.
  @internal
  static bdk.Descriptor privateDescriptor(
    bdk.DescriptorSecretKey secretKey, {
    required ScriptType scriptType,
    required BitcoinNetwork network,
    required int accountIndex,
    required bdk.KeychainKind keychain,
  }) {
    final chain = keychain == bdk.KeychainKind.external_ ? 0 : 1;
    final key =
        "${secretKey.toString()}/${scriptType.purpose}'/"
        "${network.coinType}'/$accountIndex'/$chain/*";
    return bdk.Descriptor(
      descriptor: switch (scriptType) {
        ScriptType.bip84 => 'wpkh($key)',
        ScriptType.bip49 => 'sh(wpkh($key))',
        ScriptType.bip44 => 'pkh($key)',
      },
      networkKind: network.isMainnet
          ? bdk.NetworkKind.main
          : bdk.NetworkKind.test,
    );
  }
}

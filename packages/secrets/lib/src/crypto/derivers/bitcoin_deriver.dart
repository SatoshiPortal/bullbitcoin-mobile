import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/domain.dart';
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

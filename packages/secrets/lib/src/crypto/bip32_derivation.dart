import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bs58check/bs58check.dart' as base58;
import 'package:convert/convert.dart' as conv;
import 'package:primitives/primitives.dart';

/// Pure-Dart BIP32 derivation. Ported verbatim from the app's
/// `lib/core/utils/bip32_derivation.dart`, re-pointed onto `primitives` types.
/// INTERNAL — never exported.
class Bip32Derivation {
  /// 8-hex master fingerprint of the seed.
  static String fingerprintHex(Uint8List seedBytes) {
    final root = bip32.Bip32Keys.fromSeed(seedBytes);
    return conv.hex.encode(root.fingerprint);
  }

  /// Neutered (public) account-level key at `m/{purpose}'/{coinType}'/{account}'`.
  static bip32.Bip32Keys accountXpub({
    required Uint8List seedBytes,
    required ScriptType scriptType,
    required Network network,
    int account = 0,
  }) {
    final root = bip32.Bip32Keys.fromSeed(seedBytes);
    final path = "m/${scriptType.purpose}'/${network.coinType}'/$account'";
    return root.derivePath(path).neutered;
  }

  /// Root xprv (base58). Bitcoin testnet uses the tprv version bytes.
  static String xprvFromSeed(Uint8List seedBytes, Network network) {
    final nw = network == Network.bitcoinTestnet
        ? bip32.NetworkType(
            wif: 0x80,
            bip32:
                bip32.Bip32Type(public: 0x043587CF, private: 0x04358394),
          )
        : null;
    final root = bip32.Bip32Keys.fromSeed(seedBytes, network: nw);
    return root.toBase58();
  }

  /// Re-encodes a neutered key's base58 with the [target] version bytes.
  static String convertXpub(bip32.Bip32Keys key, XpubType target) {
    final decoded = base58.decode(key.toBase58());
    final keyBytes = decoded.sublist(4);
    return base58.encode(
      Uint8List.fromList([...target.versionBytes, ...keyBytes]),
    );
  }
}

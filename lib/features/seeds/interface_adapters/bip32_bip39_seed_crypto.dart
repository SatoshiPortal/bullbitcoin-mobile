import 'dart:typed_data';

import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';
import 'package:bb_mobile/core/utils/uint_8_list_x.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_crypto_port.dart';
import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';

class Bip32Bip39SeedCrypto implements SeedCryptoPort {
  @override
  Future<String> getFingerprintFromSeedSecret(SeedSecret seedSecret) async {
    final bytes = switch (seedSecret) {
      SeedBytesSecret(:final bytes) => bytes,
      SeedMnemonicSecret(:final words, :final passphrase) => Mnemonic.fromWords(
        words: words,
        passphrase: passphrase ?? '',
      ).seed,
    };

    final root = Bip32Keys.fromSeed(Uint8List.fromList(bytes));
    final fingerprintBytes = root.fingerprint;
    final fingerprintHex = fingerprintBytes.toHexString();
    return fingerprintHex;
  }
}

import 'dart:typed_data';

import 'package:bb_mobile/core/primitives/secrets/secret.dart';
import 'package:bb_mobile/core/utils/uint_8_list_x.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_crypto_port.dart';
import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';

class Bip32And39SecretCrypto implements SecretCryptoPort {
  @override
  Future<String> getFingerprintFromSecret(Secret seedSecret) async {
    final bytes = switch (seedSecret) {
      SeedSecret(:final bytes) => bytes,
      MnemonicSecret(:final words, :final passphrase) => Mnemonic.fromWords(
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

import 'dart:typed_data';

import 'package:bb_mobile/core/utils/uint_8_list_x.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_crypto_port.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/mnemonic_words.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/passphrase.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/seed_bytes.dart';
import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';

class Bip32And39SecretCrypto implements SecretCryptoPort {
  @override
  Fingerprint getFingerprintFromMnemonic({
    required MnemonicWords mnemonicWords,
    Passphrase? passphrase,
  }) {
    final bytes = Mnemonic.fromWords(
      words: mnemonicWords.value,
      passphrase: passphrase?.value ?? '',
    ).seed;

    return _deriveFingerprintFromSeedBytes(bytes);
  }

  @override
  Fingerprint getFingerprintFromSeedBytes(SeedBytes seedBytes) {
    return _deriveFingerprintFromSeedBytes(seedBytes.value);
  }

  Fingerprint _deriveFingerprintFromSeedBytes(List<int> seedBytes) {
    final root = Bip32Keys.fromSeed(Uint8List.fromList(seedBytes));
    final fingerprintBytes = root.fingerprint;
    final fingerprintHex = fingerprintBytes.toHexString();
    return Fingerprint.fromHex(fingerprintHex);
  }
}

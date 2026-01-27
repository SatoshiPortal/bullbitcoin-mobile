import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/mnemonic_words.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/passphrase.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/seed_bytes.dart';

abstract interface class SecretCryptoPort {
  Fingerprint getFingerprintFromMnemonic({
    required MnemonicWords mnemonicWords,
    Passphrase? passphrase,
  });

  Fingerprint getFingerprintFromSeedBytes(SeedBytes seedBytes);
}

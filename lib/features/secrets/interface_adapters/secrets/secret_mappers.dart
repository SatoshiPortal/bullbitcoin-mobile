import 'package:bb_mobile/features/secrets/domain/entities/secret_entity.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/mnemonic_words.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/passphrase.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/seed_bytes.dart';
import 'package:bb_mobile/features/secrets/interface_adapters/secrets/secret_model.dart';

extension SecretModelMappersX on SecretModel {
  Secret toDomain(String fingerprint) {
    final fp = Fingerprint(fingerprint);
    return switch (this) {
      BytesSeedModel(:final bytes) => SeedSecret(
        fingerprint: fp,
        bytes: SeedBytes(bytes),
      ),
      MnemonicSeedModel(:final mnemonicWords, :final passphrase) =>
        MnemonicSecret(
          fingerprint: fp,
          words: MnemonicWords(mnemonicWords),
          passphrase: passphrase != null ? Passphrase(passphrase) : null,
        ),
    };
  }
}

extension SecretDomainMappersX on Secret {
  SecretModel toModel() {
    return switch (this) {
      SeedSecret(bytes: final bytes) => SecretModel.bytes(bytes: bytes.value),
      MnemonicSecret(words: final words, passphrase: final passphrase) =>
        SecretModel.mnemonic(
          mnemonicWords: words.value,
          passphrase: passphrase?.value,
        ),
    };
  }
}

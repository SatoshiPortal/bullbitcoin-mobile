import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';
import 'package:bb_mobile/features/seeds/interface_adapters/seed_secrets/seed_secret_model.dart';

extension SeedSecretModelMappersX on SeedSecretModel {
  SeedSecret toDomain() {
    return switch (this) {
      BytesSeedModel(:final bytes) => SeedBytesSecret(bytes),
      MnemonicSeedModel(:final mnemonicWords, :final passphrase) =>
        SeedMnemonicSecret(words: mnemonicWords, passphrase: passphrase),
    };
  }
}

extension SeedSecretDomainMappersX on SeedSecret {
  SeedSecretModel toModel() {
    return switch (this) {
      SeedBytesSecret(bytes: final bytes) => SeedSecretModel.bytes(
        bytes: bytes,
      ),
      SeedMnemonicSecret(words: final words, passphrase: final passphrase) =>
        SeedSecretModel.mnemonic(mnemonicWords: words, passphrase: passphrase),
    };
  }
}

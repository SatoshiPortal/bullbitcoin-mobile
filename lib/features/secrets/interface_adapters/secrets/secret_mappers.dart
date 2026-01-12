import 'package:bb_mobile/core/primitives/secrets/secret.dart';
import 'package:bb_mobile/features/secrets/interface_adapters/secrets/secret_model.dart';

extension SecretModelMappersX on SecretModel {
  Secret toDomain() {
    return switch (this) {
      BytesSeedModel(:final bytes) => SeedSecret(bytes),
      MnemonicSeedModel(:final mnemonicWords, :final passphrase) =>
        MnemonicSecret(words: mnemonicWords, passphrase: passphrase),
    };
  }
}

extension SecretDomainMappersX on Secret {
  SecretModel toModel() {
    return switch (this) {
      SeedSecret(bytes: final bytes) => SecretModel.bytes(bytes: bytes),
      MnemonicSecret(words: final words, passphrase: final passphrase) =>
        SecretModel.mnemonic(mnemonicWords: words, passphrase: passphrase),
    };
  }
}

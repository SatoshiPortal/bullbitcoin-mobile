import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'seed_secret_model.freezed.dart';
part 'seed_secret_model.g.dart';

@freezed
sealed class SeedSecretModel with _$SeedSecretModel {
  const SeedSecretModel._();

  const factory SeedSecretModel.bytes({required List<int> bytes}) =
      BytesSeedModel; // Do not rename BytesSeedModel since freezed from json relies on it

  const factory SeedSecretModel.mnemonic({
    required List<String> mnemonicWords,
    String? passphrase,
  }) =
      MnemonicSeedModel; // Do not rename MnemonicSeedModel since freezed from json relies on it

  factory SeedSecretModel.fromSeedSecret(SeedSecret seedSecret) {
    return switch (seedSecret) {
      SeedBytesSecret(bytes: final bytes) => SeedSecretModel.bytes(
        bytes: bytes,
      ),
      SeedMnemonicSecret(words: final words, passphrase: final passphrase) =>
        SeedSecretModel.mnemonic(mnemonicWords: words, passphrase: passphrase),
    };
  }

  SeedSecret toSeedSecret() {
    return switch (this) {
      BytesSeedModel(:final bytes) => SeedBytesSecret(bytes),
      MnemonicSeedModel(:final mnemonicWords, :final passphrase) =>
        SeedMnemonicSecret(words: mnemonicWords, passphrase: passphrase),
    };
  }

  factory SeedSecretModel.fromJson(Map<String, dynamic> json) =>
      _$SeedSecretModelFromJson(json);
}

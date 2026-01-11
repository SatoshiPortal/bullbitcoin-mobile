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

  factory SeedSecretModel.fromJson(Map<String, dynamic> json) =>
      _$SeedSecretModelFromJson(json);
}

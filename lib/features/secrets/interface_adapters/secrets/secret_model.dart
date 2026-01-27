import 'package:freezed_annotation/freezed_annotation.dart';

part 'secret_model.freezed.dart';
part 'secret_model.g.dart';

@freezed
sealed class SecretModel with _$SecretModel {
  const SecretModel._();

  const factory SecretModel.bytes({required List<int> bytes}) =
      BytesSeedModel; // Do not rename BytesSeedModel since freezed from json relies on it

  const factory SecretModel.mnemonic({
    required List<String> mnemonicWords,
    String? passphrase,
  }) =
      MnemonicSeedModel; // Do not rename MnemonicSeedModel since freezed from json relies on it

  factory SecretModel.fromJson(Map<String, dynamic> json) =>
      _$SecretModelFromJson(json);
}

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/uint_8_list_x.dart';
import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'seed_model.freezed.dart';
part 'seed_model.g.dart';

@freezed
sealed class SeedModel with _$SeedModel {
  const SeedModel._();

  const factory SeedModel.fromEntropy({
    required List<int> entropy,
    required String passphrase,
  }) = EntropySeedModel;

  factory SeedModel.fromMnemonic({
    required List<String> mnemonicWords,
    Language language = Language.english,
    String? passphrase,
  }) {
    final mnemonic = Mnemonic.fromWords(
      words: mnemonicWords,
      language: language,
      passphrase: passphrase ?? '',
    );

    return EntropySeedModel(
      entropy: mnemonic.entropy,
      passphrase: mnemonic.passphrase,
    );
  }

  /// Convert `Seed` entity to `SeedModel`
  factory SeedModel.fromEntity(Seed entity) {
    return switch (entity) {
      EntropySeed(:final entropy, :final passphrase) => SeedModel.fromEntropy(
        entropy: entropy,
        passphrase: passphrase ?? '',
      ),
    };
  }

  Seed toEntity() {
    return switch (this) {
      EntropySeedModel(:final entropy, :final passphrase) => Seed.fromEntropy(
        entropy: entropy,
        passphrase: passphrase,
      ),
    };
  }

  factory SeedModel.fromJson(Map<String, dynamic> json) =>
      _$SeedModelFromJson(json);

  Mnemonic toMnemonic({Language language = Language.english}) =>
      Mnemonic(entropy, language, passphrase: passphrase);

  List<int> get bytes {
    return switch (this) {
      EntropySeedModel() => toMnemonic().seed,
    };
  }

  String get masterFingerprint {
    final root = Bip32Keys.fromSeed(Uint8List.fromList(bytes));
    final fingerprintBytes = root.fingerprint;
    final fingerprintHex = fingerprintBytes.toHexString();
    return fingerprintHex;
  }
}

import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:convert/convert.dart' as convert;
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'seed.freezed.dart';

@freezed
sealed class Seed with _$Seed {
  const Seed._();

  const factory Seed.fromEntropy({
    required Uint8List entropy,
    String? passphrase,
  }) = EntropySeed;

  factory Seed.fromMnemonic({
    required List<String> words,
    Language language = Language.english,
    String? passphrase,
  }) {
    final mnemonic = Mnemonic.fromWords(
      words: words,
      language: language,
      passphrase: passphrase ?? '',
    );

    return EntropySeed(
      entropy: Uint8List.fromList(mnemonic.entropy),
      passphrase: mnemonic.passphrase,
    );
  }

  Mnemonic toMnemonic({Language language = Language.english}) =>
      Mnemonic(entropy, language, passphrase: passphrase ?? '');

  String get hexBytes => convert.hex.encode(bytes);

  Uint8List get bytes {
    return switch (this) {
      EntropySeed() => Uint8List.fromList(toMnemonic().seed),
    };
  }

  String get masterFingerprint {
    final root = Bip32Keys.fromSeed(Uint8List.fromList(bytes));
    final fingerprintBytes = root.fingerprint;
    final fingerprintHex = convert.hex.encode(fingerprintBytes);
    return fingerprintHex;
  }
}

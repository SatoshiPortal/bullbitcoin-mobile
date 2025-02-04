import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'seed.freezed.dart';

@freezed
sealed class Seed with _$Seed {
  const Seed._();

  /// Mnemonic-based seed
  const factory Seed.mnemonic({
    required List<String> mnemonicWords,
    String? passphrase,
  }) = MnemonicSeed;

  /// Compute seed fingerprint
  String get fingerprint {
    return when(
      mnemonic: (mnemonicWords, passphrase) {
        final mnemonic = mnemonicWords.join(' ');
        final seed =
            bip39.mnemonicToSeed(mnemonic, passphrase: passphrase ?? '');
        final root = bip32.BIP32.fromSeed(seed);
        final fingerprint = root.fingerprint;
        return fingerprint
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
      },
    );
  }
}

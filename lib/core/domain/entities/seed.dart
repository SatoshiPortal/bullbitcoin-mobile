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

  Uint8List get seedBytes {
    return when(
      mnemonic: (mnemonicWords, passphrase) => bip39.mnemonicToSeed(
        mnemonicWords.join(' '),
        passphrase: passphrase ?? '',
      ),
    );
  }

  String get seedHex {
    return seedBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String get masterFingerprint {
    final root = bip32.BIP32.fromSeed(seedBytes);
    final fingerprintBytes = root.fingerprint;
    final fingerprintHex =
        fingerprintBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return fingerprintHex;
  }
}

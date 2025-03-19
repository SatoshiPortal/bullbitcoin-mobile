import 'package:bb_mobile/_utils/uint_8_list_x.dart';
import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'seed.freezed.dart';

@freezed
sealed class Seed with _$Seed {
  const Seed._();

  /// Bytes-based seed
  const factory Seed.bytes({
    required Uint8List bytes,
  }) = BytesSeed;

  /// Mnemonic-based seed
  const factory Seed.mnemonic({
    required List<String> mnemonicWords,
    String? passphrase,
  }) = MnemonicSeed;

  Uint8List get bytes {
    return when(
      bytes: (b) => b,
      mnemonic: (mnemonicWords, passphrase) => bip39.mnemonicToSeed(
        mnemonicWords.join(' '),
        passphrase: passphrase ?? '',
      ),
    );
  }

  String get hex => bytes.toHexString();

  String get masterFingerprint {
    final root = bip32.BIP32.fromSeed(bytes);
    final fingerprintBytes = root.fingerprint;
    final fingerprintHex = fingerprintBytes.toHexString();
    return fingerprintHex;
  }
}

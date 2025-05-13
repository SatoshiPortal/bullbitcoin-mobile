import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'new_seed_entity.freezed.dart';

@freezed
sealed class NewSeedEntity with _$NewSeedEntity {
  const NewSeedEntity._();

  /// Bytes-based seed
  const factory NewSeedEntity.bytes({required Uint8List bytes}) = NewBytesSeed;

  /// Mnemonic-based seed
  const factory NewSeedEntity.mnemonic({
    required List<String> mnemonicWords,
    String? passphrase,
  }) = NewMnemonicSeed;

  Uint8List get bytes {
    return switch (this) {
      NewBytesSeed(:final bytes) => bytes,
      NewMnemonicSeed(:final mnemonicWords, :final passphrase) =>
        Uint8List.fromList(
          Mnemonic.fromWords(
            words: mnemonicWords,
            passphrase: passphrase ?? '',
          ).seed,
        ),
    };
  }

  String get hex => bytes.toHexString();

  String get masterFingerprint {
    final root = bip32.BIP32.fromSeed(bytes);
    final fingerprintBytes = root.fingerprint;
    final fingerprintHex = fingerprintBytes.toHexString();
    return fingerprintHex;
  }
}

extension NewUint8ListX on Uint8List {
  String toHexString() =>
      map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List fromHexString(String hex) {
    final length = hex.length;
    final bytes = Uint8List(length ~/ 2);
    for (var i = 0; i < length; i += 2) {
      bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }
}

import 'package:bb_mobile/core_deprecated/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core_deprecated/utils/uint_8_list_x.dart';
import 'package:bip32_keys/bip32_keys.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'seed_model.freezed.dart';
part 'seed_model.g.dart';

@freezed
sealed class SeedModel with _$SeedModel {
  const SeedModel._();

  const factory SeedModel.bytes({required List<int> bytes}) = BytesSeedModel;

  const factory SeedModel.mnemonic({
    required List<String> mnemonicWords,
    String? passphrase,
  }) = MnemonicSeedModel;

  List<int> get bytes {
    return switch (this) {
      BytesSeedModel(:final bytes) => bytes,
      MnemonicSeedModel(:final mnemonicWords, :final passphrase) =>
        Mnemonic.fromWords(
          words: mnemonicWords,
          passphrase: passphrase ?? '',
        ).seed,
    };
  }

  String get masterFingerprint {
    final root = Bip32Keys.fromSeed(Uint8List.fromList(bytes));
    final fingerprintBytes = root.fingerprint;
    final fingerprintHex = fingerprintBytes.toHexString();
    return fingerprintHex;
  }

  /// Convert `Seed` entity to `SeedModel`
  factory SeedModel.fromEntity(Seed entity) {
    return switch (entity) {
      BytesSeed(:final bytes) => SeedModel.bytes(bytes: bytes as List<int>),
      MnemonicSeed(:final mnemonicWords, :final passphrase) =>
        SeedModel.mnemonic(
          mnemonicWords: mnemonicWords,
          passphrase: passphrase,
        ),
    };
  }

  Seed toEntity() {
    return switch (this) {
      BytesSeedModel(:final bytes) => Seed.bytes(
        bytes: Uint8List.fromList(bytes),
        masterFingerprint: masterFingerprint,
      ),
      MnemonicSeedModel(:final mnemonicWords, :final passphrase) =>
        Seed.mnemonic(
          mnemonicWords: mnemonicWords,
          passphrase: passphrase,
          bytes: Uint8List.fromList(bytes),
          masterFingerprint: masterFingerprint,
        ),
    };
  }

  factory SeedModel.fromJson(Map<String, dynamic> json) =>
      _$SeedModelFromJson(json);
}

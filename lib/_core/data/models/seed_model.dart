import 'package:bb_mobile/_core/domain/entities/seed.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'seed_model.freezed.dart';
part 'seed_model.g.dart';

enum SeedType { bytes, mnemonic }

@freezed
sealed class SeedModel with _$SeedModel {
  const SeedModel._();

  const factory SeedModel.bytes({
    required SeedType type, // Always SeedType.bytes
    required List<int> bytes,
  }) = BytesSeedModel;

  const factory SeedModel.mnemonic({
    required SeedType type, // Always SeedType.mnemonic
    required List<String> mnemonicWords,
    String? passphrase,
  }) = MnemonicSeedModel;

  /// Convert `Seed` entity to `SeedModel`
  factory SeedModel.fromEntity(Seed entity) {
    return entity.when(
      bytes: (bytes) => SeedModel.bytes(
        type: SeedType.bytes,
        bytes: bytes,
      ),
      mnemonic: (mnemonicWords, passphrase) => SeedModel.mnemonic(
        type: SeedType.mnemonic,
        mnemonicWords: mnemonicWords,
        passphrase: passphrase,
      ),
    );
  }

  Seed toEntity() {
    return when(
      bytes: (type, bytes) => Seed.bytes(
        bytes: Uint8List.fromList(bytes),
      ),
      mnemonic: (type, mnemonicWords, passphrase) => Seed.mnemonic(
        mnemonicWords: mnemonicWords,
        passphrase: passphrase,
      ),
    );
  }

  factory SeedModel.fromJson(Map<String, dynamic> json) =>
      _$SeedModelFromJson(json);
}

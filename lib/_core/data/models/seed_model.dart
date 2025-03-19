import 'package:bb_mobile/_core/domain/entities/seed.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'seed_model.freezed.dart';
part 'seed_model.g.dart';

@freezed
sealed class SeedModel with _$SeedModel {
  const SeedModel._();

  const factory SeedModel.bytes({
    required List<int> bytes,
  }) = BytesSeedModel;

  const factory SeedModel.mnemonic({
    required List<String> mnemonicWords,
    String? passphrase,
  }) = MnemonicSeedModel;

  /// Convert `Seed` entity to `SeedModel`
  factory SeedModel.fromEntity(Seed entity) {
    return entity.when(
      bytes: (bytes) => SeedModel.bytes(
        bytes: bytes,
      ),
      mnemonic: (mnemonicWords, passphrase) => SeedModel.mnemonic(
        mnemonicWords: mnemonicWords,
        passphrase: passphrase,
      ),
    );
  }

  Seed toEntity() {
    return when(
      bytes: (bytes) => Seed.bytes(
        bytes: Uint8List.fromList(bytes),
      ),
      mnemonic: (mnemonicWords, passphrase) => Seed.mnemonic(
        mnemonicWords: mnemonicWords,
        passphrase: passphrase,
      ),
    );
  }

  factory SeedModel.fromJson(Map<String, dynamic> json) =>
      _$SeedModelFromJson(json);
}

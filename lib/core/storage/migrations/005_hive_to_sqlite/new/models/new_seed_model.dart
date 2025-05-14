import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/entities/new_seed_entity.dart'
    show NewBytesSeed, NewMnemonicSeed, NewSeedEntity;
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'new_seed_model.freezed.dart';
part 'new_seed_model.g.dart';

@freezed
sealed class NewSeedModel with _$NewSeedModel {
  const NewSeedModel._();

  const factory NewSeedModel.bytes({required List<int> bytes}) =
      NewBytesSeedModel;

  const factory NewSeedModel.mnemonic({
    required List<String> mnemonicWords,
    String? passphrase,
  }) = NewMnemonicSeedModel;

  /// Convert `NewSeedEntity` entity to `NewSeedModel`
  factory NewSeedModel.fromEntity(NewSeedEntity entity) {
    return switch (entity) {
      NewBytesSeed(:final bytes) => NewSeedModel.bytes(
        bytes: bytes as List<int>,
      ),
      NewMnemonicSeed(:final mnemonicWords, :final passphrase) =>
        NewSeedModel.mnemonic(
          mnemonicWords: mnemonicWords,
          passphrase: passphrase,
        ),
    };
  }

  NewSeedEntity toEntity() {
    return switch (this) {
      NewBytesSeedModel(:final bytes) => NewSeedEntity.bytes(
        bytes: Uint8List.fromList(bytes),
      ),
      NewMnemonicSeedModel(:final mnemonicWords, :final passphrase) =>
        NewSeedEntity.mnemonic(
          mnemonicWords: mnemonicWords,
          passphrase: passphrase,
        ),
    };
  }

  factory NewSeedModel.fromJson(Map<String, dynamic> json) =>
      _$NewSeedModelFromJson(json);
}

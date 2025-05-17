import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/datasources/bip85_mapping_datasource.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/bip85_mapping_model.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/domain/entity/bip85_application.dart';
import 'package:bb_mobile/core/seed/domain/entity/bip85_bip39_language.dart';
import 'package:bb_mobile/core/seed/domain/entity/bip85_bip39_word_count.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';

class SeedRepositoryImpl implements SeedRepository {
  final SeedDatasource _seedDatasource;
  final Bip85MappingDatasource _bip85MappingDatasource;

  const SeedRepositoryImpl({
    required SeedDatasource seedDatasource,
    required Bip85MappingDatasource bip85MappingDatasource,
  }) : _seedDatasource = seedDatasource,
       _bip85MappingDatasource = bip85MappingDatasource;

  @override
  Future<MnemonicSeed> createFromMnemonic({
    required List<String> mnemonicWords,
    String? passphrase,
  }) async {
    final model = SeedModel.mnemonic(
      mnemonicWords: mnemonicWords,
      passphrase: passphrase,
    );
    await _seedDatasource.store(
      fingerprint: model.masterFingerprint,
      seed: model,
    );
    return model.toEntity() as MnemonicSeed;
  }

  @override
  Future<MnemonicSeed> createBip85DerivedFromMasterSeed({
    required String masterSeedFingerprint,
    required Bip85Bip39Language language,
    required Bip85Bip39WordCount wordCount,
    required int accountIndex,
    String? passphrase,
  }) async {
    // TODO: Derive the mnemonic words from the master seed following BIP85
    // The existing Bip32Derivation class can be added to and used for this purpose probably.
    final derivationPath =
        "m/83696968'/${Bip85Application.bip39.derivationPathValue}/${language.derivationPathValue}/${wordCount.derivationPathValue}/$accountIndex'";
    final mnemonicWords = <String>[];

    final model = SeedModel.mnemonic(
      mnemonicWords: mnemonicWords,
      passphrase: passphrase,
    );

    // Make sure we have the seed stored
    await _seedDatasource.store(
      fingerprint: model.masterFingerprint,
      seed: model,
    );
    // Now we can store the bip85 relation between the master seed and the derived mnemonic seed
    final bip85Model = Bip85MappingModel(
      seedFingerprint: model.masterFingerprint,
      masterSeedFingerprint: masterSeedFingerprint,
      bip85DerivationPath: derivationPath,
    );

    await _bip85MappingDatasource.store(bip85Model);

    return model.toEntity(bip85MasterSeedFingerprint: masterSeedFingerprint)
        as MnemonicSeed;
  }

  @override
  Future<Seed> createFromBytes({required Uint8List bytes}) async {
    final model = SeedModel.bytes(bytes: bytes);
    await _seedDatasource.store(
      fingerprint: model.masterFingerprint,
      seed: model,
    );

    return model.toEntity();
  }

  @override
  Future<Seed> get(String fingerprint) async {
    final (seed, bip85Mapping) =
        await (
          _seedDatasource.get(fingerprint),
          _bip85MappingDatasource.fetch(fingerprint),
        ).wait;

    return seed.toEntity(
      bip85MasterSeedFingerprint: bip85Mapping?.masterSeedFingerprint,
    );
  }

  @override
  Future<bool> exists(String fingerprint) =>
      _seedDatasource.exists(fingerprint);

  @override
  Future<void> delete(String fingerprint) =>
      _seedDatasource.delete(fingerprint);
}

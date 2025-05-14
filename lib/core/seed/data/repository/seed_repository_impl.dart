import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';

class SeedRepositoryImpl implements SeedRepository {
  final SeedDatasource _source;

  const SeedRepositoryImpl({required SeedDatasource source}) : _source = source;

  @override
  Future<MnemonicSeed> createFromMnemonic({
    required List<String> mnemonicWords,
    String? passphrase,
  }) async {
    final model = SeedModel.mnemonic(
      mnemonicWords: mnemonicWords,
      passphrase: passphrase,
    );
    await _source.store(fingerprint: model.masterFingerprint, seed: model);
    return model.toEntity() as MnemonicSeed;
  }

  @override
  Future<Seed> createFromBytes({required Uint8List bytes}) async {
    final model = SeedModel.bytes(bytes: bytes);
    await _source.store(fingerprint: model.masterFingerprint, seed: model);

    return model.toEntity();
  }

  @override
  Future<Seed> get(String fingerprint) async {
    final model = await _source.get(fingerprint);
    return model.toEntity();
  }

  @override
  Future<bool> exists(String fingerprint) => _source.exists(fingerprint);

  @override
  Future<void> delete(String fingerprint) => _source.delete(fingerprint);
}

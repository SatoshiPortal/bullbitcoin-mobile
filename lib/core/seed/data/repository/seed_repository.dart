import 'dart:typed_data';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';

class SeedRepository {
  final SeedDatasource _source;

  const SeedRepository({required SeedDatasource source}) : _source = source;

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

  Future<Seed> createFromBytes({required Uint8List bytes}) async {
    final model = SeedModel.bytes(bytes: bytes);
    await _source.store(fingerprint: model.masterFingerprint, seed: model);
    return model.toEntity();
  }

  Future<Seed> get(String fingerprint) async {
    final model = await _source.get(fingerprint);
    return model.toEntity();
  }

  Future<bool> exists(String fingerprint) => _source.exists(fingerprint);

  Future<void> delete(String fingerprint) => _source.delete(fingerprint);
}

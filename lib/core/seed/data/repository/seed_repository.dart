import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/secure_storage_data_source_impl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
    final rootToken = RootIsolateToken.instance!;
    final seed = await compute(
      _getSeedInIsolate,
      _IsolateParams(fingerprint: fingerprint, rootToken: rootToken),
    );
    return seed;
  }

  Future<bool> exists(String fingerprint) => _source.exists(fingerprint);

  Future<void> delete(String fingerprint) => _source.delete(fingerprint);
}

class _IsolateParams {
  final String fingerprint;
  final RootIsolateToken rootToken;

  _IsolateParams({required this.fingerprint, required this.rootToken});
}

Future<Seed> _getSeedInIsolate(_IsolateParams params) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(params.rootToken);
  final secureStorage = SecureStorageDatasourceImpl(
    const FlutterSecureStorage(),
  );
  final seedDatasource = SeedDatasource(secureStorage: secureStorage);

  final model = await seedDatasource.get(params.fingerprint);
  return model.toEntity();
}

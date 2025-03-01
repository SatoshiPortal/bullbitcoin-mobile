import 'dart:convert';

import 'package:bb_mobile/_core/data/datasources/key_value_storage/key_value_storage_data_source.dart';
import 'package:bb_mobile/_core/data/models/seed_model.dart';
import 'package:bb_mobile/_core/domain/entities/seed.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';

class SeedRepositoryImpl implements SeedRepository {
  final KeyValueStorageDataSource<String> _storage;

  static const _keyPrefix = 'seed_';

  const SeedRepositoryImpl(this._storage);

  @override
  Future<void> storeSeed(Seed seed) {
    final key = '$_keyPrefix${seed.masterFingerprint}';
    final model = SeedModel.fromEntity(seed);
    final value = jsonEncode(model.toJson());
    return _storage.saveValue(key: key, value: value);
  }

  @override
  Future<Seed> getSeed(String fingerprint) async {
    final key = '$_keyPrefix$fingerprint';
    final value = await _storage.getValue(key);
    if (value == null) {
      throw SeedNotFoundException(
        'Seed not found for fingerprint: $fingerprint',
      );
    }

    final json = jsonDecode(value) as Map<String, dynamic>;
    final model = SeedModel.fromJson(json);
    final seed = model.toEntity();

    return seed;
  }

  @override
  Future<bool> hasSeed(String fingerprint) {
    final key = '$_keyPrefix$fingerprint';
    return _storage.hasValue(key);
  }

  @override
  Future<void> deleteSeed(String fingerprint) {
    final key = '$_keyPrefix$fingerprint';
    return _storage.deleteValue(key);
  }
}

class SeedNotFoundException implements Exception {
  final String message;

  const SeedNotFoundException(this.message);
}

import 'dart:convert';

import 'package:bb_mobile/_core/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/_core/data/models/seed_model.dart';
import 'package:bb_mobile/_utils/constants.dart';

abstract class SeedDatasource {
  Future<void> store({
    required String fingerprint,
    required SeedModel seed,
  });
  Future<SeedModel> get(String fingerprint);
  Future<bool> exists(String fingerprint);
  Future<void> delete(String fingerprint);
}

class SeedDatasourceImpl implements SeedDatasource {
  final KeyValueStorageDatasource<String> _secureStorage;

  const SeedDatasourceImpl({
    required KeyValueStorageDatasource<String> secureStorage,
  }) : _secureStorage = secureStorage;

  @override
  Future<void> store({required String fingerprint, required SeedModel seed}) {
    final key = _seedKey(fingerprint);
    final value = jsonEncode(seed.toJson());
    return _secureStorage.saveValue(key: key, value: value);
  }

  @override
  Future<SeedModel> get(String fingerprint) async {
    final key = _seedKey(fingerprint);
    final value = await _secureStorage.getValue(key);
    if (value == null) {
      throw SeedNotFoundException(
        'Seed not found for fingerprint: $fingerprint',
      );
    }

    final json = jsonDecode(value) as Map<String, dynamic>;
    final seed = SeedModel.fromJson(json);

    return seed;
  }

  @override
  Future<bool> exists(String fingerprint) {
    final key = _seedKey(fingerprint);
    return _secureStorage.hasValue(key);
  }

  @override
  Future<void> delete(String fingerprint) {
    final key = _seedKey(fingerprint);
    return _secureStorage.deleteValue(key);
  }

  String _seedKey(String fingerprint) =>
      '${SecureStorageKeyPrefixConstants.seed}$fingerprint';
}

class SeedNotFoundException implements Exception {
  final String message;

  const SeedNotFoundException(this.message);
}

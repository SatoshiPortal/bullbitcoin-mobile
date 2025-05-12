import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_seed.dart'
    show Seed;
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_storage.dart'
    show SecureStorage;

class WalletSensitiveStorageRepository {
  WalletSensitiveStorageRepository({required SecureStorage secureStorage})
    : _secureStorage = secureStorage;

  final SecureStorage _secureStorage;

  Future<List<String>> getMnemonic({required String fingerprintIndex}) async {
    try {
      final value = await _secureStorage.getValue(fingerprintIndex);
      if (value == null) throw 'No Seed with index $fingerprintIndex';
      final obj = jsonDecode(value) as Map<String, dynamic>;
      final seed = Seed.fromJson(obj);
      return seed.mnemonicList();
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}

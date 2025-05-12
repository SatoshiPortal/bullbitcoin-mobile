import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_seed.dart'
    show OldSeed;
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_storage.dart'
    show OldSecureStorage;

class OldWalletSensitiveStorageRepository {
  OldWalletSensitiveStorageRepository({required OldSecureStorage secureStorage})
    : _secureStorage = secureStorage;

  final OldSecureStorage _secureStorage;

  Future<List<String>> getMnemonic({required String fingerprintIndex}) async {
    try {
      final value = await _secureStorage.getValue(fingerprintIndex);
      if (value == null) throw 'No OldSeed with index $fingerprintIndex';
      final obj = jsonDecode(value) as Map<String, dynamic>;
      final seed = OldSeed.fromJson(obj);
      return seed.mnemonicList();
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}

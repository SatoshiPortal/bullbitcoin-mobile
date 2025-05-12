import 'dart:convert';

import 'package:bb_mobile/z_migration/migrations.dart' show SecureStorage;
import 'package:bb_mobile/z_migration/old_seed.dart' show Seed;

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

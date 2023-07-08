import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';

class StorageKeys {
  static const securityKey = 'securityKey';
  static const wallets = 'wallets';
  static const settings = 'settings';
  static const seed = 'seed';
}

abstract class IStorage {
  Future<Err?> saveValue({
    required String key,
    required String value,
  });

  Future<(Map<String, String>?, Err?)> getAll();

  Future<(String?, Err?)> getValue(
    String key,
  );

  Future<Err?> deleteValue(
    String key,
  );

  Future<Err?> deleteAll();
}

Future<(SecureStorage, HiveStorage)> setupStorage() async {
  final secureStorage = SecureStorage();
  const password = 'satoshi';
  final (_, err) = await secureStorage.getValue(StorageKeys.seed);
  if (err != null) secureStorage.saveValue(key: StorageKeys.seed, value: password);
  final hiveStorage = HiveStorage(password: password);
  return (secureStorage, hiveStorage);
}

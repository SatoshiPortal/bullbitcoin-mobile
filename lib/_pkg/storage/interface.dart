import 'package:bb_mobile/_pkg/error.dart';

enum StorageKeys {
  securityKey('securityKey'),
  wallets('wallets'),
  settings('settings');

  const StorageKeys(this.name);
  final String name;
}

abstract class IStorage {
  Future<Err?> saveValue({
    required StorageKeys key,
    required String value,
  });

  Future<(Map<String, String>?, Err?)> getAll();

  Future<(String?, Err?)> getValue(
    StorageKeys key,
  );

  Future<Err?> deleteValue(
    StorageKeys key,
  );

  Future<Err?> deleteAll();

  Future<Err?> saveWallet({
    required String key,
    required String value,
  });

  Future<(String?, Err?)> getWallet(
    String key,
  );

  Future<Err?> deleteWallet(
    String key,
  );
}

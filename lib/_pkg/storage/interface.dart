import 'package:bb_mobile/_pkg/error.dart';

class StorageKeys {
  static const securityKey = 'securityKey';
  static const wallets = 'wallets';
  static const settings = 'settings';
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

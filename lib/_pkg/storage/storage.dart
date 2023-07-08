import 'dart:convert';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:hive/hive.dart';

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
  final hiveStorage = HiveStorage();
  // await secureStorage.deleteAll();

  final (password, err) = await secureStorage.getValue(StorageKeys.seed);
  if (err != null) {
    final password = Hive.generateSecureKey();
    secureStorage.saveValue(key: StorageKeys.seed, value: base64UrlEncode(password));
    await hiveStorage.init(password: password);
  } else
    await hiveStorage.init(password: base64Url.decode(password!));

  // await hiveStorage.deleteAll();

  return (secureStorage, hiveStorage);
}

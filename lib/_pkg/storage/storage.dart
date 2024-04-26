import 'dart:convert';

import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/migration.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/locator.dart';
import 'package:hive/hive.dart';

class StorageKeys {
  static const securityKey = 'securityKey';
  static const seeds = 'seeds';
  static const wallets = 'wallets';
  static const settings = 'settings';
  static const network = 'network';
  static const networkFees = 'networkFees';
  static const currency = 'currency';
  static const lighting = 'lighting';
  static const swapTxSensitive = 'swapTxSensitive';
  static const hiveEncryption = 'hiveEncryptionKey';
  static const version = 'version';
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

  final (out, errrOut) = await secureStorage.getAll();
  print(jsonEncode(out));

  var (version, errr) = await secureStorage.getValue(StorageKeys.version);
  if (errr != null) {
    print('::::no storage version saved');
    print(errr);

    version = bbVersion;
    await secureStorage.saveValue(key: StorageKeys.version, value: bbVersion);
    // } else if (version != bbVersion) {
    // await doMigration(version!, bbVersion, hiveStorage);
    // await secureStorage.deleteAll();
    // await secureStorage.saveValue(key: StorageKeys.version, value: bbVersion);
  }

  final (password, err) = await secureStorage.getValue(StorageKeys.hiveEncryption);
  if (err != null) {
    print('::::new encryption key generated');
    final password = Hive.generateSecureKey();
    secureStorage.saveValue(
      key: StorageKeys.hiveEncryption,
      value: base64UrlEncode(password),
    );
    await hiveStorage.init(password: password);
  } else
    await hiveStorage.init(password: base64Url.decode(password!));

  if (version != bbVersion) {
    await doMigration(version!, bbVersion, secureStorage, hiveStorage);
    await secureStorage.saveValue(key: StorageKeys.version, value: bbVersion);
  }
  // if (errr == null && version != bbVersion) await hiveStorage.deleteAll();

  return (secureStorage, hiveStorage);
}

import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_storage_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

class OldSecureStorage {
  final storage = const FlutterSecureStorage();

  Future<String?> getValue(String key) async {
    return await storage.read(key: key);
  }
}

class OldHiveStorage {
  OldHiveStorage();
  late Box<String> _box;

  Future init({required List<int> password}) async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    final cipher = HiveAesCipher(password);
    _box = await Hive.openBox('store', encryptionCipher: cipher);
  }

  String? getValue(String key) => _box.get(key);

  Map<String, String> getAll() {
    final Map<String, String> data = {};
    _box.toMap().forEach((key, value) {
      data[key as String] = value;
    });
    return data;
  }
}

Future<(OldSecureStorage, OldHiveStorage)> setupStorage() async {
  final secureStorage = OldSecureStorage();
  final hiveStorage = OldHiveStorage();

  final password = await secureStorage.getValue(
    OldStorageKeys.hiveEncryption.name,
  );
  if (password == null) debugPrint('migration not needed');

  debugPrint('migration maybe needed but also maybe already migrated');
  await hiveStorage.init(password: base64Url.decode(password!));
  return (secureStorage, hiveStorage);
}

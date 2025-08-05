import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_storage_keys.dart';
import 'package:bb_mobile/core/storage/secure_storage.dart';
import 'package:hive/hive.dart' show Box, Hive, HiveAesCipher;
import 'package:path_provider/path_provider.dart'
    show getApplicationDocumentsDirectory;

class OldHiveDatasource {
  final Box<dynamic> box;

  OldHiveDatasource(this.box);

  static Future<Box> getBox() async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    final secureStorage = SecureStorage.init();
    final password = await secureStorage.read(
      key: OldStorageKeys.hiveEncryption.name,
    );

    if (password == null) return await Hive.openBox('store');

    final cipher = HiveAesCipher(base64Url.decode(password));
    final box = await Hive.openBox('store', encryptionCipher: cipher);
    return box;
  }

  String? getValue(String key) => box.get(key) as String?;

  Future<void> saveValue({required String key, required String value}) async {
    await box.put(key, value);
  }
}

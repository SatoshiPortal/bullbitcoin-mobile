import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_storage_keys.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart' show Box, Hive, HiveAesCipher;
import 'package:path_provider/path_provider.dart'
    show getApplicationDocumentsDirectory;

class OldHiveDatasource {
  final Box<dynamic> box;

  OldHiveDatasource(this.box);

  static Future<OldHiveDatasource> init() async {
    final password = await const FlutterSecureStorage().read(
      key: OldStorageKeys.hiveEncryption.name,
    );

    if (password == null) throw Exception('hive was not initialized');

    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    final cipher = HiveAesCipher(base64Url.decode(password));
    final box = await Hive.openBox('store', encryptionCipher: cipher);
    return OldHiveDatasource(box);
  }

  String? getValue(String key) => box.get(key) as String?;

  Future<void> saveValue({required String key, required String value}) async {
    await box.put(key, value);
  }
}

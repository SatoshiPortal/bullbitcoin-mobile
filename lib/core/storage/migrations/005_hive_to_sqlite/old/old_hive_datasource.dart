import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart' show Box, Hive, HiveAesCipher;
import 'package:path_provider/path_provider.dart'
    show getApplicationDocumentsDirectory;

class OldHiveDatasource {
  final Box<dynamic> box;

  OldHiveDatasource(this.box);

  static Future<Box> getBox(FlutterSecureStorage secureStorage) async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    final box = await Hive.openBox('store');
    return box;
  }

  String? getValue(String key) => box.get(key) as String?;

  Future<void> saveValue({required String key, required String value}) async {
    await box.put(key, value);
  }
}

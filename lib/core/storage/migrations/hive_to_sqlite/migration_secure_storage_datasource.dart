import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MigrationSecureStorageDatasource {
  final FlutterSecureStorage _storage;

  MigrationSecureStorageDatasource() : _storage = const FlutterSecureStorage();

  Future<void> store({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> fetch({required String key}) async {
    return await _storage.read(key: key);
  }
}

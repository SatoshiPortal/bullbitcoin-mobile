import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static FlutterSecureStorage init() {
    return const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );
  }
}

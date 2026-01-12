import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageDatasourceImpl implements KeyValueStorageDatasource<String> {
  final FlutterSecureStorage _storage;

  SecureStorageDatasourceImpl(this._storage);

  @override
  Future<void> saveValue({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<Map<String, String>> getAll() async {
    final firstUnlockThisDeviceReadResults = await _storage.readAll();

    // The following is needed because we used to have no background processing needs
    // but now we do, so some values may have been stored with more restrictive accessibility
    // (unlocked) then the current default (first unlock this device).
    if (firstUnlockThisDeviceReadResults.isNotEmpty) {
      return firstUnlockThisDeviceReadResults;
    }

    final unlockedReadResults = await _storage.readAll(
      iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
    );
    for (final entry in unlockedReadResults.entries) {
      // Re-save the values with the default accessibility for future reads and
      // reads from background processes.
      await _storage.write(key: entry.key, value: entry.value);
    }

    return unlockedReadResults;
  }

  @override
  Future<String?> getValue(String key) async {
    final firstUnlockThisDeviceReadResult = await _storage.read(key: key);

    // The following is needed because we used to have no background processing needs
    // but now we do, so some values may have been stored with more restrictive accessibility
    // (unlocked) then the current default (first unlock this device).
    if (firstUnlockThisDeviceReadResult != null) {
      return firstUnlockThisDeviceReadResult;
    }

    final unlockedReadResult = await _storage.read(
      key: key,
      iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
    );
    if (unlockedReadResult != null) {
      // Re-save the value with the default accessibility for future reads and
      // reads from background processes.
      await _storage.write(key: key, value: unlockedReadResult);
    }
    return unlockedReadResult;
  }

  @override
  Future<bool> hasValue(String key) async {
    final firstUnlockThisDeviceCheck = await _storage.containsKey(key: key);

    // The following is needed because we used to have no background processing needs
    // but now we do, so some values may have been stored with more restrictive accessibility
    // (unlocked) then the current default (first unlock this device).
    if (firstUnlockThisDeviceCheck) {
      return true;
    }

    final unlockedCheck = await _storage.containsKey(
      key: key,
      iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
    );

    if (unlockedCheck) {
      final value = await _storage.read(
        key: key,
        iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
      );
      if (value != null) {
        // Re-save the value with the default accessibility for future reads and
        // reads from background processes.
        await _storage.write(key: key, value: value);
      }
    }
    return unlockedCheck;
  }

  @override
  Future<void> deleteValue(String key) async {
    await _storage.delete(key: key);
  }

  @override
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}

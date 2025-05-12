import 'dart:convert';

import 'package:bb_mobile/z_migration/migrate_labels.dart';
import 'package:bb_mobile/z_migration/migrate_settings.dart';
import 'package:bb_mobile/z_migration/migrate_wallet_metadatas.dart';
import 'package:bb_mobile/z_migration/old_wallet_sensitive_storage_repository.dart'
    show WalletSensitiveStorageRepository;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

enum StorageKeys {
  securityKey('securityKey'),
  seeds('seeds'),
  wallets('wallets'),
  settings('settings'),
  network('network'),
  networkFees('networkFees'),
  currency('currency'),
  lighting('lighting'),
  swapTxSensitive('swapTxSensitive'),
  hiveEncryption('hiveEncryptionKey'),
  version('version'),
  payjoin('payjoin');

  final String name;
  const StorageKeys(this.name);
}

class SecureStorage {
  final storage = const FlutterSecureStorage();

  Future<String?> getValue(String key) async {
    return await storage.read(key: key);
  }
}

class HiveStorage {
  HiveStorage();
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

Future<(SecureStorage, HiveStorage)> setupStorage() async {
  final secureStorage = SecureStorage();
  final hiveStorage = HiveStorage();

  final password =
      await secureStorage.getValue(StorageKeys.hiveEncryption.name);
  if (password == null) debugPrint('migration not needed');

  debugPrint('migration maybe needed but also maybe already migrated');
  await hiveStorage.init(password: base64Url.decode(password!));
  return (secureStorage, hiveStorage);
}

class MigrateHiveToSqlite {
  static Future<void> migrateFromHiveToSqlite() async {
    try {
      final (secure, hive) = await setupStorage();
      // final settings = await managers.settings.get();
      // if (settings.isNotEmpty) return;

      for (final storageKey in StorageKeys.values) {
        final value = hive.getValue(storageKey.name);
        debugPrint('${storageKey.name}: $value');
      }

      final settings = fetchSettings(hive);
      print(
          'settings: ${settings.unitInSats} | ${settings.currencyCode} | ${settings.hideAmount}');

      final labels = await fetchLabels(hive);
      print('labels: $labels');

      final metadatas = fetchWalletMetadatas(hive);
      print('metadatas: $metadatas');

      for (final w in metadatas) {
        print('w: ${w.mnemonicFingerprint}');
        print('w: ${w.sourceFingerprint}');

        final mnemonic =
            await WalletSensitiveStorageRepository(secureStorage: secure)
                .getMnemonic(fingerprintIndex: w.mnemonicFingerprint);
        print('mnemonic: $mnemonic');
      }
    } catch (e) {
      debugPrint('Error during migrations: $e');
    }
  }
}

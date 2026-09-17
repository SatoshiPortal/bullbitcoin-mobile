import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/secure_storage_data_source_impl.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

class StorageLocator {
  static const _probeKey = '__bull_secure_storage_prewarm__';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      // Never auto-delete data on errors. The v10 default is true.
      resetOnError: false,
      // Never run a migration. 10.3.x reads v9 cipher markers from
      // their real location and leaves data that still decrypts alone,
      // so nothing here needs re-encrypting on our behalf.
      migrateOnAlgorithmChange: false,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Starts Android's lazy `flutter_secure_storage` cipher initialization early.
  ///
  /// The plugin may spend several seconds in a cold fsync on first use; calling this before the wizard overlaps that local work with it. There is one storage generation, so every install gets the same instance it will open anyway. Failures are logged and left to the first real read.
  static Future<void> prewarmSecureStorage() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _storage.containsKey(key: _probeKey);
    } catch (e) {
      log.warning('Secure storage prewarm failed: ${e.runtimeType}');
    }
  }

  /// Registers the app's shared secure storage.
  ///
  /// This used to probe between `flutter_secure_storage` 9 and 10 and
  /// persist the answer in a `seed_store_type` flag, so that 6.5.2
  /// Android installs whose data lived in Jetpack Security's
  /// EncryptedSharedPreferences could keep reading it through the fss9
  /// plugin. That cohort was warned to back up and reinstall from 6.10.0
  /// onwards, and the fss9 plugin has now been dropped: there is one
  /// storage generation, chosen here, with no fallback.
  ///
  /// Note that the user's seeds no longer live behind this datasource.
  /// The `secrets` package owns its own `flutter_secure_storage`
  /// instance and hands one out to nobody — what is registered here
  /// serves pin_code, swaps, exchange and app_unlock.
  static Future<void> registerDatasources(GetIt locator) async {
    locator.registerLazySingleton<KeyValueStorageDatasource<String>>(
      () => SecureStorageDatasourceImpl(_storage),
      instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
    );
  }
}

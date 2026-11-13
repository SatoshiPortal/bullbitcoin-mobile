import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/secure_storage_data_source_impl.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

class StorageLocator {
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
    final storage = const FlutterSecureStorage(
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

    locator.registerLazySingleton<KeyValueStorageDatasource<String>>(
      () => SecureStorageDatasourceImpl(storage),
      instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
    );
  }
}

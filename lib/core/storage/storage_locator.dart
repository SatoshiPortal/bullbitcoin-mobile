import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/secure_storage_data_source_impl.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:get_it/get_it.dart';
import 'package:secrets/secrets.dart';

class StorageLocator {
  /// Delegates Android's lazy storage initialization to its sole owner.
  static Future<void> prewarmSecureStorage() => Secrets.prewarmStorage();

  /// Keeps legacy consumers behind an adapter; the plugin is owned only by secrets.
  static Future<void> registerDatasources(GetIt locator) async {
    locator.registerLazySingleton<KeyValueStorageDatasource<String>>(
      () => SecureStorageDatasourceImpl(locator<Secrets>().applicationStorage),
      instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
    );
  }
}

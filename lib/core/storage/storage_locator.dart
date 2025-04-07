import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/secure_storage_data_source_impl.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageLocator {
  static void registerDatasourcer() {
    locator.registerLazySingleton<KeyValueStorageDatasource<String>>(
      () => SecureStorageDatasourceImpl(
        const FlutterSecureStorage(),
      ),
      instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
    );
  }
}

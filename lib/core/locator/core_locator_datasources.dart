
import 'package:bb_mobile/core/exchange/data/datasources/bitcoin_price_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/file_storage_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/google_drive_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/hive_storage_datasource_impl.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/secure_storage_data_source_impl.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/tor/data/datasources/tor_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/locator.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

Future<void> registerDatasources() async {
  // Data sources
  //  - Tor
  if (!locator.isRegistered<TorDatasource>()) {
    // Register TorDatasource as a singleton async
    // This ensures Tor is properly initialized before it's used
    locator.registerSingletonAsync<TorDatasource>(
      () async {
        final tor = await TorDatasource.init();
        return tor;
      },
    );
  }
  await locator.isReady<TorDatasource>();
  //  - Secure storage
  locator.registerLazySingleton<KeyValueStorageDatasource<String>>(
    () => SecureStorageDatasourceImpl(
      const FlutterSecureStorage(),
    ),
    instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
  );
  //  - Bull Bitcoin API
  final bbApiDatasource = BitcoinPriceDatasource(
    bullBitcoinHttpClient: Dio(
      BaseOptions(baseUrl: 'https://api.bullbitcoin.com'),
    ),
  );
  locator.registerLazySingleton<BitcoinPriceDatasource>(() => bbApiDatasource);
  //  - Swaps
  final boltzSwapsBox =
      await Hive.openBox<String>(HiveBoxNameConstants.boltzSwaps);
  locator.registerLazySingleton<KeyValueStorageDatasource<String>>(
    () => HiveStorageDatasourceImpl<String>(boltzSwapsBox),
    instanceName: LocatorInstanceNameConstants
        .boltzSwapsHiveStorageDatasourceInstanceName,
  );

  // Repositories
  // Register TorRepository right after TorDatasource
  // - Google Drive Datasource
  locator.registerLazySingleton<GoogleDriveAppDatasource>(
    () => GoogleDriveAppDatasource(),
  );

  // - RecoverBullRemoteDatasource
  locator.registerLazySingleton<RecoverBullRemoteDatasource>(
    () => RecoverBullRemoteDatasource(
      address: Uri.parse(ApiServiceConstants.bullBitcoinKeyServerApiUrlPath),
    ),
  );
  // - FileStorageDataSource

  locator.registerLazySingleton<FileStorageDatasource>(
    () => FileStorageDatasource(filePicker: FilePicker.platform),
  );
}

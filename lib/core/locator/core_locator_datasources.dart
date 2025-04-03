import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/blockchain/data/datasources/lwk_liquid_blockchain_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bitcoin_price_datasource.dart';
import 'package:bb_mobile/core/labels/data/label_storage_datasource.dart';
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

  //  - Labels
  final labelsBox = await Hive.openBox<String>(HiveBoxNameConstants.labels);
  final labelsByRefBox =
      await Hive.openBox<String>(HiveBoxNameConstants.labelsByRef);

  // Register the Hive storage datasource for labels
  locator.registerLazySingleton<KeyValueStorageDatasource<String>>(
    () => HiveStorageDatasourceImpl<String>(labelsBox),
    instanceName:
        LocatorInstanceNameConstants.labelsHiveStorageDatasourceInstanceName,
  );
  locator.registerLazySingleton<KeyValueStorageDatasource<String>>(
    () => HiveStorageDatasourceImpl<String>(labelsByRefBox),
    instanceName: LocatorInstanceNameConstants
        .labelByRefHiveStorageDatasourceInstanceName,
  );

  // Register the LabelStorageDatasource
  locator.registerLazySingleton<LabelStorageDatasource>(
    () => LabelStorageDatasource(
      mainLabelStorage: locator<KeyValueStorageDatasource<String>>(
        instanceName: LocatorInstanceNameConstants
            .labelsHiveStorageDatasourceInstanceName,
      ),
      refLabelStorage: locator<KeyValueStorageDatasource<String>>(
        instanceName: LocatorInstanceNameConstants
            .labelByRefHiveStorageDatasourceInstanceName,
      ),
    ),
  );

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

  // Blockchain datasources
  locator.registerLazySingleton<LiquidBlockchainDatasource>(
    () => const LwkLiquidBlockchainDatasource(),
    instanceName:
        LocatorInstanceNameConstants.lwkLiquidBlockchainDatasourceInstanceName,
  );
  locator.registerLazySingleton<BitcoinBlockchainDatasource>(
    () => const BdkBitcoinBlockchainDatasource(),
    instanceName:
        LocatorInstanceNameConstants.bdkBitcoinBlockchainDatasourceInstanceName,
  );
}

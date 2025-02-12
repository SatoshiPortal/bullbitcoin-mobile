import 'package:bb_mobile/core/data/datasources/exchange_data_source.dart';
import 'package:bb_mobile/core/data/datasources/impl/bull_bitcoin_exchange_datasource_impl.dart';
import 'package:bb_mobile/core/data/datasources/impl/hive_storage_datasource_impl.dart';
import 'package:bb_mobile/core/data/datasources/impl/secure_storage_data_source_impl.dart';
import 'package:bb_mobile/core/data/datasources/key_value_storage_data_source.dart';
import 'package:bb_mobile/features/app_startup/locator/di_setup.dart';
import 'package:bb_mobile/features/app_unlock/locator/di_setup.dart';
import 'package:bb_mobile/features/fiat_currencies/locator/di_setup.dart';
import 'package:bb_mobile/features/language/locator/di_setup.dart';
import 'package:bb_mobile/features/onboarding/locator/di_setup.dart';
import 'package:bb_mobile/features/pin_code/locator/di_setup.dart';
import 'package:bb_mobile/features/recover_wallet/locator/di_setup.dart';
import 'package:bb_mobile/features/wallet/locator/di_setup.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';

GetIt locator = GetIt.instance;
const String secureStorageInstanceName = 'secureStorage';
const String hiveSettingsBoxName = 'settings';
const String settingsStorageInstanceName = 'settingsStorage';
const String bullBitcoinExchangeInstanceName = 'bullBitcoinExchange';

// TODO: call this in the main function before runApp
Future<void> initializeDI() async {
  locator.enableRegisteringMultipleInstancesOfOneType();

  // Always register core dependencies first since feature specific dependencies
  //  may depend on them.
  await _registerCoreDependencies();
  setupAppStartupDependencies();
  setupLanguageDependencies();
  setupOnboardingDependencies();
  setupRecoverWalletDependencies();
  setupFiatCurrenciesDependencies();
  await setupWalletDependencies();
  setupPinCodeDependencies();
  setupAppUnlockDependencies();
}

// Core dependencies like Hive, file storage, secure storage
Future<void> _registerCoreDependencies() async {
  // Data sources
  locator.registerLazySingleton<KeyValueStorageDataSource<String>>(
    () => SecureStorageDataSourceImpl(
      const FlutterSecureStorage(),
    ),
    instanceName: secureStorageInstanceName,
  );
  final settingsBox = await Hive.openBox<String>(hiveSettingsBoxName);
  locator.registerLazySingleton<KeyValueStorageDataSource<String>>(
    () => HiveStorageDataSourceImpl<String>(settingsBox),
    instanceName: settingsStorageInstanceName,
  );
  locator.registerLazySingleton<ExchangeDataSource>(
    () => BullBitcoinExchangeDataSourceImpl(),
    instanceName: bullBitcoinExchangeInstanceName,
  );
}

import 'package:bb_mobile/core/exchange/data/datasources/api_key_storage_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bull_bitcoin_price_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bull_bitcoin_user_datasource.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_rate_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_currency_to_sats_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_api_key_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_api_key_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/locator.dart';
import 'package:dio/dio.dart';

class ExchangeLocator {
  static void registerDatasources() {
    // BB Exchange API Key Storage
    locator.registerLazySingleton<ApiKeyStorageDatasource>(
      () => ApiKeyStorageDatasource(
        secureStorage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );

    locator.registerLazySingleton<BullBitcoinPriceDatasource>(
      () => BullBitcoinPriceDatasource(
        bullBitcoinHttpClient: Dio(
          BaseOptions(baseUrl: 'https://api.bullbitcoin.com'),
        ),
      ),
    );

    locator.registerLazySingleton<BullBitcoinUserDatasource>(
      () => BullBitcoinUserDatasource(
        bullBitcoinHttpClient: Dio(
          BaseOptions(baseUrl: 'https://api05.bullbitcoin.dev'),
        ),
      ),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<ExchangeRateRepository>(
      () => ExchangeRateRepositoryImpl(
        bitcoinPriceDatasource: locator<BullBitcoinPriceDatasource>(),
      ),
    );
  }

  static void registerUseCases() {
    locator.registerFactory<ConvertCurrencyToSatsAmountUsecase>(
      () => ConvertCurrencyToSatsAmountUsecase(
        exchangeRateRepository: locator<ExchangeRateRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<ConvertSatsToCurrencyAmountUsecase>(
      () => ConvertSatsToCurrencyAmountUsecase(
        exchangeRateRepository: locator<ExchangeRateRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<GetAvailableCurrenciesUsecase>(
      () => GetAvailableCurrenciesUsecase(
        exchangeRateRepository: locator<ExchangeRateRepository>(),
      ),
    );

    locator.registerFactory<SaveApiKeyUsecase>(
      () =>
          SaveApiKeyUsecase(apiKeyStorage: locator<ApiKeyStorageDatasource>()),
    );

    locator.registerFactory<GetApiKeyUsecase>(
      () => GetApiKeyUsecase(apiKeyStorage: locator<ApiKeyStorageDatasource>()),
    );

    locator.registerFactory<GetUserSummaryUsecase>(
      () => GetUserSummaryUsecase(
        userDatasource: locator<BullBitcoinUserDatasource>(),
      ),
    );
  }
}

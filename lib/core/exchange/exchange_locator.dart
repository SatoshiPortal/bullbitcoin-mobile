import 'package:bb_mobile/core/exchange/data/datasources/bull_bitcoin_price_datasource.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_rate_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_currency_to_sats_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/locator.dart';
import 'package:dio/dio.dart';

class ExchangeLocator {
  static void registerDatasources() {
    locator.registerLazySingleton<BullBitcoinPriceDatasource>(
      () => BullBitcoinPriceDatasource(
        bullBitcoinHttpClient: Dio(
          BaseOptions(baseUrl: 'https://api.bullbitcoin.com'),
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
  }
}

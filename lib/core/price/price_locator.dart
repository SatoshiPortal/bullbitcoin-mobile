import 'package:bb_mobile/core/price/data/bitcoin_price_repository_impl.dart';
import 'package:bb_mobile/core/price/data/datasources/bullbitcoin_price_datasource.dart';
import 'package:bb_mobile/core/price/data/datasources/local_price_history_datasource.dart';
import 'package:bb_mobile/core/price/data/price_history_repository_impl.dart';
import 'package:bb_mobile/core/price/domain/repositories/bitcoin_price_repository.dart';
import 'package:bb_mobile/core/price/domain/repositories/price_history_repository.dart';
import 'package:bb_mobile/core/price/domain/usecases/convert_currency_to_sats_amount_usecase.dart';
import 'package:bb_mobile/core/price/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/price/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/price/domain/usecases/get_price_history_usecase.dart';
import 'package:bb_mobile/core/price/domain/usecases/refresh_price_history_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

class PriceLocator {
  static void registerDatasources(GetIt locator) {
    locator.registerLazySingleton<BullbitcoinPriceDatasource>(
      () => BullbitcoinPriceDatasource(
        bullbitcoinApiHttpClient: Dio(
          BaseOptions(baseUrl: ApiServiceConstants.bbApiUrl),
        ),
      ),
      instanceName: 'mainnetBullbitcoinPriceDatasource',
    );

    locator.registerLazySingleton<BullbitcoinPriceDatasource>(
      () => BullbitcoinPriceDatasource(
        bullbitcoinApiHttpClient: Dio(
          BaseOptions(baseUrl: ApiServiceConstants.bbApiTestUrl),
        ),
      ),
      instanceName: 'testnetBullbitcoinPriceDatasource',
    );

    locator.registerLazySingleton<LocalPriceHistoryDatasource>(
      () => LocalPriceHistoryDatasource(db: locator<SqliteDatabase>()),
    );
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<BitcoinPriceRepository>(
      () => BitcoinPriceRepositoryImpl(
        bullbitcoinPriceDatasource: locator<BullbitcoinPriceDatasource>(
          instanceName: 'mainnetBullbitcoinPriceDatasource',
        ),
      ),
      instanceName: 'mainnetBitcoinPriceRepository',
    );

    locator.registerLazySingleton<BitcoinPriceRepository>(
      () => BitcoinPriceRepositoryImpl(
        bullbitcoinPriceDatasource: locator<BullbitcoinPriceDatasource>(
          instanceName: 'testnetBullbitcoinPriceDatasource',
        ),
      ),
      instanceName: 'testnetBitcoinPriceRepository',
    );

    locator.registerLazySingleton<PriceHistoryRepository>(
      () => PriceHistoryRepositoryImpl(
        bullbitcoinPriceDatasource: locator<BullbitcoinPriceDatasource>(
          instanceName: 'mainnetBullbitcoinPriceDatasource',
        ),
        localPriceHistoryDatasource: locator<LocalPriceHistoryDatasource>(),
      ),
    );
  }

  static void registerUseCases(GetIt locator) {
    locator.registerFactory<ConvertCurrencyToSatsAmountUsecase>(
      () => ConvertCurrencyToSatsAmountUsecase(
        mainnetBitcoinPriceRepository: locator<BitcoinPriceRepository>(
          instanceName: 'mainnetBitcoinPriceRepository',
        ),
        testnetBitcoinPriceRepository: locator<BitcoinPriceRepository>(
          instanceName: 'testnetBitcoinPriceRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<ConvertSatsToCurrencyAmountUsecase>(
      () => ConvertSatsToCurrencyAmountUsecase(
        mainnetBitcoinPriceRepository: locator<BitcoinPriceRepository>(
          instanceName: 'mainnetBitcoinPriceRepository',
        ),
        testnetBitcoinPriceRepository: locator<BitcoinPriceRepository>(
          instanceName: 'testnetBitcoinPriceRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<GetAvailableCurrenciesUsecase>(
      () => GetAvailableCurrenciesUsecase(
        mainnetBitcoinPriceRepository: locator<BitcoinPriceRepository>(
          instanceName: 'mainnetBitcoinPriceRepository',
        ),
        testnetBitcoinPriceRepository: locator<BitcoinPriceRepository>(
          instanceName: 'testnetBitcoinPriceRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<GetPriceHistoryUsecase>(
      () => GetPriceHistoryUsecase(
        priceHistoryRepository: locator<PriceHistoryRepository>(),
      ),
    );

    locator.registerFactory<RefreshPriceHistoryUsecase>(
      () => RefreshPriceHistoryUsecase(
        priceHistoryRepository: locator<PriceHistoryRepository>(),
      ),
    );
  }
}

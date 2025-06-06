import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_api_key_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_order_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_rate_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_user_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/accelerate_buy_order_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/confirm_buy_order_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_currency_to_sats_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/create_buy_order_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/delete_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/list_all_orders_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/refresh_buy_order_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/locator.dart';
import 'package:dio/dio.dart';

class ExchangeLocator {
  static void registerDatasources() {
    // BB Exchange API Key Storage
    locator.registerLazySingleton<BullbitcoinApiKeyDatasource>(
      () => BullbitcoinApiKeyDatasource(
        secureStorage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );

    locator.registerLazySingleton<BullbitcoinApiDatasource>(
      () => BullbitcoinApiDatasource(
        bullbitcoinApiHttpClient: Dio(
          BaseOptions(baseUrl: ApiServiceConstants.bbApiUrl),
        ),
      ),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<ExchangeRateRepository>(
      () => ExchangeRateRepositoryImpl(
        bitcoinPriceDatasource: locator<BullbitcoinApiDatasource>(),
      ),
    );

    locator.registerLazySingleton<ExchangeApiKeyRepository>(
      () => ExchangeApiKeyRepositoryImpl(
        bullbitcoinApiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
      ),
    );

    locator.registerLazySingleton<ExchangeUserRepository>(
      () => ExchangeUserRepositoryImpl(
        bullbitcoinApiDatasource: locator<BullbitcoinApiDatasource>(),
        bullbitcoinApiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
      ),
    );

    locator.registerLazySingleton<ExchangeOrderRepository>(
      () => ExchangeOrderRepositoryImpl(
        bullbitcoinApiDatasource: locator<BullbitcoinApiDatasource>(),
        bullbitcoinApiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
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

    locator.registerFactory<SaveExchangeApiKeyUsecase>(
      () => SaveExchangeApiKeyUsecase(
        exchangeApiKeyRepository: locator<ExchangeApiKeyRepository>(),
      ),
    );

    locator.registerFactory<DeleteExchangeApiKeyUsecase>(
      () => DeleteExchangeApiKeyUsecase(
        exchangeApiKeyRepository: locator<ExchangeApiKeyRepository>(),
      ),
    );

    locator.registerFactory<GetExchangeUserSummaryUsecase>(
      () => GetExchangeUserSummaryUsecase(
        exchangeUserRepository: locator<ExchangeUserRepository>(),
      ),
    );

    // Order usecases
    locator.registerFactory<CreateBuyOrderUsecase>(
      () => CreateBuyOrderUsecase(
        exchangeOrderRepository: locator<ExchangeOrderRepository>(),
      ),
    );

    locator.registerFactory<ConfirmBuyOrderUsecase>(
      () => ConfirmBuyOrderUsecase(
        exchangeOrderRepository: locator<ExchangeOrderRepository>(),
      ),
    );

    locator.registerFactory<RefreshBuyOrderUsecase>(
      () => RefreshBuyOrderUsecase(
        exchangeOrderRepository: locator<ExchangeOrderRepository>(),
      ),
    );

    locator.registerFactory<GetOrderUsecase>(
      () => GetOrderUsecase(
        exchangeOrderRepository: locator<ExchangeOrderRepository>(),
      ),
    );

    locator.registerFactory<ListAllOrdersUsecase>(
      () => ListAllOrdersUsecase(
        exchangeOrderRepository: locator<ExchangeOrderRepository>(),
      ),
    );

    locator.registerFactory<AccelerateBuyOrderUsecase>(
      () => AccelerateBuyOrderUsecase(
        exchangeOrderRepository: locator<ExchangeOrderRepository>(),
      ),
    );
  }
}

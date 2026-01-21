import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/exchange_support_chat_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/price_local_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/price_remote_datasource.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_api_key_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_funding_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_order_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_rate_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_support_chat_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_user_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/price_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_funding_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_rate_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_support_chat_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/price_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_currency_to_sats_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/create_log_attachment_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/delete_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_funding_details_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_announcements_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_price_history_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_support_chat_message_attachment_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_support_chat_messages_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/label_exchange_orders_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/list_all_orders_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/refresh_price_history_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_user_preferences_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/buy/domain/accelerate_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/confirm_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/create_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/refresh_buy_order_usecase.dart';
import 'package:bb_mobile/features/pay/domain/create_pay_order_usecase.dart';
import 'package:bb_mobile/features/sell/domain/refresh_sell_order_usecase.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

class ExchangeLocator {
  static void registerDatasources(GetIt locator) {
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
      instanceName: 'mainnetExchangeApiDatasource',
    );

    locator.registerLazySingleton<BullbitcoinApiDatasource>(
      () => BullbitcoinApiDatasource(
        bullbitcoinApiHttpClient: Dio(
          BaseOptions(baseUrl: ApiServiceConstants.bbApiTestUrl),
        ),
      ),
      instanceName: 'testnetExchangeApiDatasource',
    );

    locator.registerLazySingleton<PriceRemoteDatasource>(
      () => BullbitcoinPriceRemoteDatasource(
        bullbitcoinApiHttpClient: Dio(
          BaseOptions(baseUrl: ApiServiceConstants.bbApiUrl),
        ),
      ),
    );

    locator.registerLazySingleton<PriceLocalDatasource>(
      () => PriceLocalDatasource(db: locator<SqliteDatabase>()),
    );

    locator.registerLazySingleton<ExchangeSupportChatDatasource>(
      () => ExchangeSupportChatDatasource(
        bullbitcoinApiHttpClient: Dio(
          BaseOptions(baseUrl: ApiServiceConstants.bbApiUrl),
        ),
      ),
      instanceName: 'mainnetExchangeSupportChatDatasource',
    );

    locator.registerLazySingleton<ExchangeSupportChatDatasource>(
      () => ExchangeSupportChatDatasource(
        bullbitcoinApiHttpClient: Dio(
          BaseOptions(baseUrl: ApiServiceConstants.bbApiTestUrl),
        ),
      ),
      instanceName: 'testnetExchangeSupportChatDatasource',
    );
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<ExchangeRateRepository>(
      () => ExchangeRateRepositoryImpl(
        bitcoinPriceDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'mainnetExchangeApiDatasource',
        ),
      ),
      instanceName: 'mainnetExchangeRateRepository',
    );
    locator.registerLazySingleton<ExchangeRateRepository>(
      () => ExchangeRateRepositoryImpl(
        bitcoinPriceDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'testnetExchangeApiDatasource',
        ),
      ),
      instanceName: 'testnetExchangeRateRepository',
    );

    locator.registerLazySingleton<ExchangeApiKeyRepository>(
      () => ExchangeApiKeyRepositoryImpl(
        bullbitcoinApiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
      ),
    );

    locator.registerLazySingleton<ExchangeUserRepository>(
      () => ExchangeUserRepositoryImpl(
        bullbitcoinApiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'mainnetExchangeApiDatasource',
        ),
        bullbitcoinApiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: false,
      ),
      instanceName: 'mainnetExchangeUserRepository',
    );
    locator.registerLazySingleton<ExchangeUserRepository>(
      () => ExchangeUserRepositoryImpl(
        bullbitcoinApiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'testnetExchangeApiDatasource',
        ),
        bullbitcoinApiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: true,
      ),
      instanceName: 'testnetExchangeUserRepository',
    );

    locator.registerLazySingleton<ExchangeOrderRepository>(
      () => ExchangeOrderRepositoryImpl(
        bullbitcoinApiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'mainnetExchangeApiDatasource',
        ),
        bullbitcoinApiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: false,
      ),
      instanceName: 'mainnetExchangeOrderRepository',
    );
    locator.registerLazySingleton<ExchangeOrderRepository>(
      () => ExchangeOrderRepositoryImpl(
        bullbitcoinApiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'testnetExchangeApiDatasource',
        ),
        bullbitcoinApiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: true,
      ),
      instanceName: 'testnetExchangeOrderRepository',
    );

    locator.registerLazySingleton<ExchangeFundingRepository>(
      () => ExchangeFundingRepositoryImpl(
        apiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'mainnetExchangeApiDatasource',
        ),
        apiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: false,
      ),
      instanceName: 'mainnetExchangeFundingRepository',
    );
    locator.registerLazySingleton<ExchangeFundingRepository>(
      () => ExchangeFundingRepositoryImpl(
        apiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'testnetExchangeApiDatasource',
        ),
        apiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: true,
      ),
      instanceName: 'testnetExchangeFundingRepository',
    );

    locator.registerLazySingleton<PriceRepository>(
      () => PriceRepositoryImpl(
        remoteDatasource: locator<PriceRemoteDatasource>(),
        localDatasource: locator<PriceLocalDatasource>(),
      ),
    );

    locator.registerLazySingleton<ExchangeSupportChatRepository>(
      () => ExchangeSupportChatRepositoryImpl(
        datasource: locator<ExchangeSupportChatDatasource>(
          instanceName: 'mainnetExchangeSupportChatDatasource',
        ),
        apiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        bullbitcoinApiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'mainnetExchangeApiDatasource',
        ),
        isTestnet: false,
      ),
      instanceName: 'mainnetExchangeSupportChatRepository',
    );

    locator.registerLazySingleton<ExchangeSupportChatRepository>(
      () => ExchangeSupportChatRepositoryImpl(
        datasource: locator<ExchangeSupportChatDatasource>(
          instanceName: 'testnetExchangeSupportChatDatasource',
        ),
        apiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        bullbitcoinApiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'testnetExchangeApiDatasource',
        ),
        isTestnet: true,
      ),
      instanceName: 'testnetExchangeSupportChatRepository',
    );
  }

  static void registerUseCases(GetIt locator) {
    locator.registerFactory<ConvertCurrencyToSatsAmountUsecase>(
      () => ConvertCurrencyToSatsAmountUsecase(
        mainnetExchangeRateRepository: locator<ExchangeRateRepository>(
          instanceName: 'mainnetExchangeRateRepository',
        ),
        testnetExchangeRateRepository: locator<ExchangeRateRepository>(
          instanceName: 'testnetExchangeRateRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<ConvertSatsToCurrencyAmountUsecase>(
      () => ConvertSatsToCurrencyAmountUsecase(
        mainnetExchangeRateRepository: locator<ExchangeRateRepository>(
          instanceName: 'mainnetExchangeRateRepository',
        ),
        testnetExchangeRateRepository: locator<ExchangeRateRepository>(
          instanceName: 'testnetExchangeRateRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<GetAvailableCurrenciesUsecase>(
      () => GetAvailableCurrenciesUsecase(
        mainnetExchangeRateRepository: locator<ExchangeRateRepository>(
          instanceName: 'mainnetExchangeRateRepository',
        ),
        testnetExchangeRateRepository: locator<ExchangeRateRepository>(
          instanceName: 'testnetExchangeRateRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<GetPriceHistoryUsecase>(
      () => GetPriceHistoryUsecase(priceRepository: locator<PriceRepository>()),
    );

    locator.registerFactory<RefreshPriceHistoryUsecase>(
      () => RefreshPriceHistoryUsecase(
        priceRepository: locator<PriceRepository>(),
      ),
    );

    locator.registerFactory<SaveExchangeApiKeyUsecase>(
      () => SaveExchangeApiKeyUsecase(
        exchangeApiKeyRepository: locator<ExchangeApiKeyRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<DeleteExchangeApiKeyUsecase>(
      () => DeleteExchangeApiKeyUsecase(
        settingsRepository: locator<SettingsRepository>(),
        exchangeApiKeyRepository: locator<ExchangeApiKeyRepository>(),
      ),
    );

    locator.registerFactory<GetExchangeUserSummaryUsecase>(
      () => GetExchangeUserSummaryUsecase(
        mainnetExchangeUserRepository: locator<ExchangeUserRepository>(
          instanceName: 'mainnetExchangeUserRepository',
        ),
        testnetExchangeUserRepository: locator<ExchangeUserRepository>(
          instanceName: 'testnetExchangeUserRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<GetAnnouncementsUsecase>(
      () => GetAnnouncementsUsecase(
        mainnetExchangeUserRepository: locator<ExchangeUserRepository>(
          instanceName: 'mainnetExchangeUserRepository',
        ),
        testnetExchangeUserRepository: locator<ExchangeUserRepository>(
          instanceName: 'testnetExchangeUserRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<CreateBuyOrderUsecase>(
      () => CreateBuyOrderUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<ConfirmBuyOrderUsecase>(
      () => ConfirmBuyOrderUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
        labelsFacade: locator<LabelsFacade>(),
      ),
    );

    locator.registerFactory<RefreshBuyOrderUsecase>(
      () => RefreshBuyOrderUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<RefreshSellOrderUsecase>(
      () => RefreshSellOrderUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<GetOrderUsecase>(
      () => GetOrderUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<ListAllOrdersUsecase>(
      () => ListAllOrdersUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<AccelerateBuyOrderUsecase>(
      () => AccelerateBuyOrderUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<GetExchangeFundingDetailsUsecase>(
      () => GetExchangeFundingDetailsUsecase(
        mainnetExchangeFundingRepository: locator<ExchangeFundingRepository>(
          instanceName: 'mainnetExchangeFundingRepository',
        ),
        testnetExchangeFundingRepository: locator<ExchangeFundingRepository>(
          instanceName: 'testnetExchangeFundingRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<SaveUserPreferencesUsecase>(
      () => SaveUserPreferencesUsecase(
        mainnetExchangeUserRepository: locator<ExchangeUserRepository>(
          instanceName: 'mainnetExchangeUserRepository',
        ),
        testnetExchangeUserRepository: locator<ExchangeUserRepository>(
          instanceName: 'testnetExchangeUserRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<PlacePayOrderUsecase>(
      () => PlacePayOrderUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<GetSupportChatMessagesUsecase>(
      () => GetSupportChatMessagesUsecase(
        mainnetRepository: locator<ExchangeSupportChatRepository>(
          instanceName: 'mainnetExchangeSupportChatRepository',
        ),
        testnetRepository: locator<ExchangeSupportChatRepository>(
          instanceName: 'testnetExchangeSupportChatRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<SendSupportChatMessageUsecase>(
      () => SendSupportChatMessageUsecase(
        mainnetRepository: locator<ExchangeSupportChatRepository>(
          instanceName: 'mainnetExchangeSupportChatRepository',
        ),
        testnetRepository: locator<ExchangeSupportChatRepository>(
          instanceName: 'testnetExchangeSupportChatRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<GetSupportChatMessageAttachmentUsecase>(
      () => GetSupportChatMessageAttachmentUsecase(
        mainnetRepository: locator<ExchangeSupportChatRepository>(
          instanceName: 'mainnetExchangeSupportChatRepository',
        ),
        testnetRepository: locator<ExchangeSupportChatRepository>(
          instanceName: 'testnetExchangeSupportChatRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<CreateLogAttachmentUsecase>(
      () => CreateLogAttachmentUsecase(),
    );

    locator.registerFactory<LabelExchangeOrdersUsecase>(
      () => LabelExchangeOrdersUsecase(
        labelsFacade: locator<LabelsFacade>(),
        listAllOrdersUsecase: locator<ListAllOrdersUsecase>(),
      ),
    );
  }

  static void setup(GetIt locator) {
    registerDatasources(locator);
    registerRepositories(locator);
    registerUseCases(locator);
  }
}

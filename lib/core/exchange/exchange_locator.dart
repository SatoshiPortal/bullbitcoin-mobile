import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/http/authenticated_bullbitcoin_dio_factory.dart';
import 'package:bb_mobile/core/exchange/data/datasources/http/bullbitcoin_api_key_provider.dart';
import 'package:bb_mobile/core/exchange/data/datasources/exchange_notification_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/exchange_support_chat_datasource.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_api_key_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_order_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_support_chat_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_user_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/services/exchange_notification_service.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_support_chat_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/create_log_attachment_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/delete_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_announcements_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_support_chat_message_attachment_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_support_chat_messages_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/list_all_orders_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_user_preferences_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
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

    // Bound order-endpoint waits when the API is reached over Tor — without
    // an explicit timeout, a hung connect lingered for tens of seconds and
    // sell-order polling spammed SEVERE on every tick. Scoped to the order
    // datasource only; the authenticated chain (recipients, fund_exchange)
    // and the support-chat client are intentionally left alone for this
    // release.
    const orderApiTimeout = ApiServiceConstants.bbApiTimeout;

    locator.registerLazySingleton<BullbitcoinApiDatasource>(
      () => BullbitcoinApiDatasource(
        bullbitcoinApiHttpClient: Dio(
          BaseOptions(
            baseUrl: ApiServiceConstants.bbApiUrl,
            connectTimeout: orderApiTimeout,
            receiveTimeout: orderApiTimeout,
            sendTimeout: orderApiTimeout,
          ),
        ),
      ),
      instanceName: 'mainnetExchangeApiDatasource',
    );

    locator.registerLazySingleton<BullbitcoinApiDatasource>(
      () => BullbitcoinApiDatasource(
        bullbitcoinApiHttpClient: Dio(
          BaseOptions(
            baseUrl: ApiServiceConstants.bbApiTestUrl,
            connectTimeout: orderApiTimeout,
            receiveTimeout: orderApiTimeout,
            sendTimeout: orderApiTimeout,
          ),
        ),
      ),
      instanceName: 'testnetExchangeApiDatasource',
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

    // WebSocket Notification Datasources
    locator.registerLazySingleton<ExchangeNotificationDatasource>(
      () => ExchangeNotificationDatasource(
        baseUrl: ApiServiceConstants.bbApiUrl,
        apiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: false,
      ),
      instanceName: 'mainnetExchangeNotificationDatasource',
    );

    locator.registerLazySingleton<ExchangeNotificationDatasource>(
      () => ExchangeNotificationDatasource(
        baseUrl: ApiServiceConstants.bbApiTestUrl,
        apiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: true,
      ),
      instanceName: 'testnetExchangeNotificationDatasource',
    );

    // Shared authenticated HTTP clients used by multiple features
    // (fund_exchange, recipients, etc.)
    locator.registerLazySingleton<BullbitcoinApiKeyProvider>(
      () => BullbitcoinApiKeyProvider(
        secureStorage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );

    locator.registerLazySingleton<Dio>(
      () => AuthenticatedBullBitcoinDioFactory.create(
        isTestnet: false,
        apiKeyProvider: locator<BullbitcoinApiKeyProvider>(),
      ),
      instanceName: 'authenticatedBullBitcoinApiClient',
    );

    locator.registerLazySingleton<Dio>(
      () => AuthenticatedBullBitcoinDioFactory.create(
        isTestnet: true,
        apiKeyProvider: locator<BullbitcoinApiKeyProvider>(),
      ),
      instanceName: 'authenticatedBullBitcoinApiTestClient',
    );
  }

  static void registerRepositories(GetIt locator) {
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
  }

  static void registerServices(GetIt locator) {
    // WebSocket Notification Service (primary/driving adapter)
    locator.registerLazySingleton<ExchangeNotificationService>(
      () => ExchangeNotificationService(
        mainnetDatasource: locator<ExchangeNotificationDatasource>(
          instanceName: 'mainnetExchangeNotificationDatasource',
        ),
        testnetDatasource: locator<ExchangeNotificationDatasource>(
          instanceName: 'testnetExchangeNotificationDatasource',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
  }
}

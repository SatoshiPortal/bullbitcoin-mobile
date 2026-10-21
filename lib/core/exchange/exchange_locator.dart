import 'package:bb_mobile/core/exchange/data/http/exchange_authentication_interceptor.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/http/authenticated_bullbitcoin_dio_factory.dart';
import 'package:bb_mobile/core/exchange/data/datasources/exchange_notification_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/exchange_support_chat_datasource.dart';
import 'package:bb_mobile/core/exchange/data/exchange_api_key_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_notification_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_order_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_support_chat_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_user_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/services/exchange_notification_service.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_notification_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_support_chat_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/create_log_attachment_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_support_chat_message_attachment_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_support_chat_messages_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/list_all_orders_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

class ExchangeLocator {
  /// Authentication is attached to each existing client configuration.
  /// Resolve the repository only when a request starts: registration precedes
  /// repository registration, and no transport owns the credential repository.
  static Dio _authenticatedClient(
    GetIt locator, {
    required bool isTestnet,
    Duration? timeout,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: isTestnet
            ? ApiServiceConstants.bbApiTestUrl
            : ApiServiceConstants.bbApiUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        sendTimeout: timeout,
      ),
    );
    addExchangeAuthentication(
      dio,
      () => locator<ExchangeApiKeyRepository>().readActiveApiKey(
        isTestnet: isTestnet,
      ),
    );
    return dio;
  }

  static void registerDatasources(GetIt locator) {
    for (final isTestnet in [false, true]) {
      final environment = isTestnet ? 'testnet' : 'mainnet';
      locator.registerLazySingleton<BullbitcoinApiDatasource>(
        () => BullbitcoinApiDatasource(
          bullbitcoinApiHttpClient: _authenticatedClient(
            locator,
            isTestnet: isTestnet,
            timeout: const Duration(seconds: 30),
          ),
        ),
        instanceName: '${environment}ExchangeApiDatasource',
      );
      locator.registerLazySingleton<ExchangeSupportChatDatasource>(
        () => ExchangeSupportChatDatasource(
          bullbitcoinApiHttpClient: _authenticatedClient(
            locator,
            isTestnet: isTestnet,
          ),
        ),
        instanceName: '${environment}ExchangeSupportChatDatasource',
      );
      locator.registerLazySingleton<ExchangeNotificationDatasource>(
        () => ExchangeNotificationDatasource(
          baseUrl: isTestnet
              ? ApiServiceConstants.bbApiTestUrl
              : ApiServiceConstants.bbApiUrl,
          readApiKey: () => locator<ExchangeApiKeyRepository>()
              .readActiveApiKey(isTestnet: isTestnet),
        ),
        instanceName: '${environment}ExchangeNotificationDatasource',
      );
    }
    locator.registerLazySingleton<Dio>(
      () => AuthenticatedBullBitcoinDioFactory.create(
        isTestnet: false,
        readApiKey: () => locator<ExchangeApiKeyRepository>().readActiveApiKey(
          isTestnet: false,
        ),
      ),
      instanceName: 'authenticatedBullBitcoinApiClient',
    );
    locator.registerLazySingleton<Dio>(
      () => AuthenticatedBullBitcoinDioFactory.create(
        isTestnet: true,
        readApiKey: () => locator<ExchangeApiKeyRepository>().readActiveApiKey(
          isTestnet: true,
        ),
      ),
      instanceName: 'authenticatedBullBitcoinApiTestClient',
    );
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<ExchangeNotificationRepository>(
      () => ExchangeNotificationRepositoryImpl(
        exchangeNotificationService: locator<ExchangeNotificationService>(),
      ),
    );

    locator.registerLazySingleton<ExchangeApiKeyRepository>(
      () => ExchangeApiKeyRepositoryImpl(
        secureStorage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );

    locator.registerLazySingleton<ExchangeUserRepository>(
      () => ExchangeUserRepositoryImpl(
        bullbitcoinApiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'mainnetExchangeApiDatasource',
        ),
      ),
      instanceName: 'mainnetExchangeUserRepository',
    );
    locator.registerLazySingleton<ExchangeUserRepository>(
      () => ExchangeUserRepositoryImpl(
        bullbitcoinApiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'testnetExchangeApiDatasource',
        ),
      ),
      instanceName: 'testnetExchangeUserRepository',
    );

    locator.registerLazySingleton<ExchangeOrderRepository>(
      () => ExchangeOrderRepositoryImpl(
        bullbitcoinApiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'mainnetExchangeApiDatasource',
        ),

        isTestnet: false,
      ),
      instanceName: 'mainnetExchangeOrderRepository',
    );
    locator.registerLazySingleton<ExchangeOrderRepository>(
      () => ExchangeOrderRepositoryImpl(
        bullbitcoinApiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'testnetExchangeApiDatasource',
        ),

        isTestnet: true,
      ),
      instanceName: 'testnetExchangeOrderRepository',
    );

    locator.registerLazySingleton<ExchangeSupportChatRepository>(
      () => ExchangeSupportChatRepositoryImpl(
        datasource: locator<ExchangeSupportChatDatasource>(
          instanceName: 'mainnetExchangeSupportChatDatasource',
        ),

        bullbitcoinApiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'mainnetExchangeApiDatasource',
        ),
      ),
      instanceName: 'mainnetExchangeSupportChatRepository',
    );

    locator.registerLazySingleton<ExchangeSupportChatRepository>(
      () => ExchangeSupportChatRepositoryImpl(
        datasource: locator<ExchangeSupportChatDatasource>(
          instanceName: 'testnetExchangeSupportChatDatasource',
        ),

        bullbitcoinApiDatasource: locator<BullbitcoinApiDatasource>(
          instanceName: 'testnetExchangeApiDatasource',
        ),
      ),
      instanceName: 'testnetExchangeSupportChatRepository',
    );
  }

  static void registerUseCases(GetIt locator) {
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

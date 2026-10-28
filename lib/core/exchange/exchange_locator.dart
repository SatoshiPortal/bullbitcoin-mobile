import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_notification_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/exchange_notification_datasource.dart';
import 'package:bb_mobile/core/exchange/data/repository/bbx_api_exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/data/repository/bbx_api_exchange_support_chat_repository.dart';
import 'package:bb_mobile/core/exchange/data/repository/bbx_api_exchange_user_repository.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_api_key_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_notification_repository_impl.dart';
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

    // WebSocket Notification Datasources
    locator.registerLazySingleton<ExchangeNotificationDatasource>(
      () => BbxApiNotificationDatasource(
        locator<BbxApiDatasource>(
          instanceName: BbxApiDatasource.mainnetInstanceName,
        ).notifications,
      ),
      instanceName: 'mainnetExchangeNotificationDatasource',
    );

    locator.registerLazySingleton<ExchangeNotificationDatasource>(
      () => BbxApiNotificationDatasource(
        locator<BbxApiDatasource>(
          instanceName: BbxApiDatasource.testnetInstanceName,
        ).notifications,
      ),
      instanceName: 'testnetExchangeNotificationDatasource',
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
        bullbitcoinApiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
      ),
    );

    locator.registerLazySingleton<ExchangeUserRepository>(
      () => BbxApiExchangeUserRepository(
        api: locator<BbxApiDatasource>(
          instanceName: BbxApiDatasource.mainnetInstanceName,
        ),
        apiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: false,
      ),
      instanceName: 'mainnetExchangeUserRepository',
    );
    locator.registerLazySingleton<ExchangeUserRepository>(
      () => BbxApiExchangeUserRepository(
        api: locator<BbxApiDatasource>(
          instanceName: BbxApiDatasource.testnetInstanceName,
        ),
        apiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: true,
      ),
      instanceName: 'testnetExchangeUserRepository',
    );

    locator.registerLazySingleton<ExchangeOrderRepository>(
      () => BbxApiExchangeOrderRepository(
        api: locator<BbxApiDatasource>(
          instanceName: BbxApiDatasource.mainnetInstanceName,
        ),
        apiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: false,
      ),
      instanceName: 'mainnetExchangeOrderRepository',
    );
    locator.registerLazySingleton<ExchangeOrderRepository>(
      () => BbxApiExchangeOrderRepository(
        api: locator<BbxApiDatasource>(
          instanceName: BbxApiDatasource.testnetInstanceName,
        ),
        apiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: true,
      ),
      instanceName: 'testnetExchangeOrderRepository',
    );

    locator.registerLazySingleton<ExchangeSupportChatRepository>(
      () => BbxApiExchangeSupportChatRepository(
        api: locator<BbxApiDatasource>(
          instanceName: BbxApiDatasource.mainnetInstanceName,
        ),
        apiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: false,
      ),
      instanceName: 'mainnetExchangeSupportChatRepository',
    );

    locator.registerLazySingleton<ExchangeSupportChatRepository>(
      () => BbxApiExchangeSupportChatRepository(
        api: locator<BbxApiDatasource>(
          instanceName: BbxApiDatasource.testnetInstanceName,
        ),
        apiKeyDatasource: locator<BullbitcoinApiKeyDatasource>(),
        isTestnet: true,
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

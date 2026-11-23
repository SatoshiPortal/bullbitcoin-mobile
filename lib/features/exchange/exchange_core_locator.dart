import 'package:bb_mobile/core/exchange/data/exchange_api_key_repository_impl.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_notification_repository_impl.dart';
import 'package:bb_mobile/features/exchange/data/services/exchange_notification_service.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_notification_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_support_chat_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/create_log_attachment_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_order_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_support_chat_message_attachment_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_support_chat_messages_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/list_all_orders_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:preferences/preferences.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/features/exchange/data/bbx_api_notification_datasource.dart';
import 'package:bb_mobile/features/exchange/data/bbx_api_order_repository.dart';
import 'package:bb_mobile/features/exchange/data/bbx_api_support_chat_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:exchange/exchange.dart';
import 'package:exchange/setup.dart';
import 'package:primitives/primitives.dart';
import 'package:get_it/get_it.dart';

import 'domain/repositories/exchange_access_repository.dart';

class ExchangeLocator {
  /// Resolves the credential only when a request starts. The app retains key
  /// custody; the package receives only this read capability.
  static Future<Result<String?, bbx.BbxFailure>> _readActiveApiKey(
    GetIt locator, {
    required bool isTestnet,
  }) async {
    final result = await locator<ExchangeApiKeyRepository>().readActiveApiKey(
      isTestnet: isTestnet,
    );
    return switch (result) {
      Ok(:final value) => Ok(value),
      Err() => const Err(bbx.BbxCredentialUnavailableFailure()),
    };
  }

  static void registerDatasources(GetIt locator) {
    locator.registerLazySingleton<Exchange>(
      () => Exchange.open(
        mainnetEndpoint: Uri.parse(ApiServiceConstants.bbApiUrl),
        testnetEndpoint: Uri.parse(ApiServiceConstants.bbApiTestUrl),
        readSession: () => readLegacyExchangeSession(
          preferences: locator<Preferences>(),
          readEpoch: () => locator<ExchangeAccessRepository>().epoch,
          readKey: locator<ExchangeApiKeyRepository>().readActiveApiKey,
        ),
      ),
    );
    for (final isTestnet in [false, true]) {
      final environment = isTestnet ? 'testnet' : 'mainnet';
      locator.registerLazySingleton<bbx.Bbx>(
        () => bbx.Bbx.open(
          endpoint: isTestnet
              ? ApiServiceConstants.bbApiTestUrl
              : ApiServiceConstants.bbApiUrl,
          readActiveApiKey: () =>
              _readActiveApiKey(locator, isTestnet: isTestnet),
          timeouts: bbx.BbxTimeouts.standard,
        ),
        instanceName: '${environment}BbxApiClient',
      );
      locator.registerLazySingleton<bbx.Bbx>(
        () => bbx.Bbx.open(
          endpoint: isTestnet
              ? ApiServiceConstants.bbApiTestUrl
              : ApiServiceConstants.bbApiUrl,
          readActiveApiKey: () =>
              _readActiveApiKey(locator, isTestnet: isTestnet),
        ),
        instanceName: '${environment}BbxApiClientWithoutTimeout',
      );
      locator.registerLazySingleton<BbxApiNotificationDatasource>(
        () => BbxApiNotificationDatasource(
          baseUrl: isTestnet
              ? ApiServiceConstants.bbApiTestUrl
              : ApiServiceConstants.bbApiUrl,
          readApiKey: () => locator<ExchangeApiKeyRepository>()
              .readActiveApiKey(isTestnet: isTestnet),
        ),
        instanceName: '${environment}ExchangeNotificationDatasource',
      );
    }
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<ExchangeNotificationRepository>(
      () => ExchangeNotificationRepositoryImpl(
        exchangeNotificationService: locator<ExchangeNotificationService>(),
      ),
    );

    locator.registerLazySingleton<ExchangeApiKeyRepository>(
      () => ExchangeApiKeyRepositoryImpl(
        secureStorage: locator<Secrets>().exchangeKeychain,
      ),
    );

    for (final isTestnet in [false, true]) {
      final environment = isTestnet ? 'testnet' : 'mainnet';
      locator.registerLazySingleton<ExchangeOrderRepository>(
        () => BbxApiOrderRepository(
          api: locator<bbx.Bbx>(instanceName: '${environment}BbxApiClient'),
          isTestnet: isTestnet,
        ),
        instanceName: '${environment}ExchangeOrderRepository',
      );
    }

    for (final environment in ['mainnet', 'testnet']) {
      locator.registerLazySingleton<ExchangeSupportChatRepository>(
        () => BbxApiSupportChatRepository(
          users: locator<bbx.Bbx>(instanceName: '${environment}BbxApiClient')
              .users,
          commcenter: locator<bbx.Bbx>(
            instanceName: '${environment}BbxApiClientWithoutTimeout',
          ).commcenter,
        ),
        instanceName: '${environment}ExchangeSupportChatRepository',
      );
    }
  }

  static void registerUseCases(GetIt locator) {
    locator.registerFactory<GetExchangeUserSummaryUsecase>(
      () => GetExchangeUserSummaryUsecase(
        exchange: locator<Exchange>(),
        settingsRepository: locator<Preferences>(),
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
        settingsRepository: locator<Preferences>(),
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
        settingsRepository: locator<Preferences>(),
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
        settingsRepository: locator<Preferences>(),
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
        settingsRepository: locator<Preferences>(),
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
        settingsRepository: locator<Preferences>(),
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
        mainnetDatasource: locator<BbxApiNotificationDatasource>(
          instanceName: 'mainnetExchangeNotificationDatasource',
        ),
        testnetDatasource: locator<BbxApiNotificationDatasource>(
          instanceName: 'testnetExchangeNotificationDatasource',
        ),
        settingsRepository: locator<Preferences>(),
      ),
    );
  }
}

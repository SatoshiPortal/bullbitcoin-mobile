import 'package:bb_mobile/core/exchange/domain/repositories/exchange_notification_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart'
    as settings_contract;
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_web_settings_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/clear_exchange_session_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_account_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_announcements_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/request_exchange_account_deletion_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/save_exchange_preferences_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/complete_exchange_authentication_usecase.dart';
import 'package:bb_mobile/features/exchange/data/exchange_auth_repository_impl.dart';
import 'package:bb_mobile/features/exchange/data/exchange_web_auth_datasource.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/watch_exchange_notifications_usecase.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:get_it/get_it.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';

class ExchangeLocator {
  static void setup(GetIt locator) {
    registerUsecases(locator);
    registerBlocs(locator);

    locator.registerLazySingleton<ExchangeFacade>(
      () => ExchangeFacade(
        getExchangeAccountUsecase: locator<GetExchangeAccountUsecase>(),
        saveExchangePreferencesUsecase:
            locator<SaveExchangePreferencesUsecase>(),
      ),
    );
  }

  /// Registers feature orchestration and view-scoped authentication dependencies.
  static void registerUsecases(GetIt locator) {
    locator.registerFactory<GetExchangeWebSettingsUsecase>(
      () => GetExchangeWebSettingsUsecase(
        settingsRepository: locator<settings_contract.SettingsRepository>(),
      ),
    );
    locator.registerFactory<GetExchangeAccountUsecase>(
      () => GetExchangeAccountUsecase(
        mainnetExchangeUserRepository: locator<ExchangeUserRepository>(
          instanceName: 'mainnetExchangeUserRepository',
        ),
        testnetExchangeUserRepository: locator<ExchangeUserRepository>(
          instanceName: 'testnetExchangeUserRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<SaveExchangePreferencesUsecase>(
      () => SaveExchangePreferencesUsecase(
        mainnetExchangeUserRepository: locator<ExchangeUserRepository>(
          instanceName: 'mainnetExchangeUserRepository',
        ),
        testnetExchangeUserRepository: locator<ExchangeUserRepository>(
          instanceName: 'testnetExchangeUserRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<GetExchangeAnnouncementsUsecase>(
      () => GetExchangeAnnouncementsUsecase(
        mainnetExchangeUserRepository: locator<ExchangeUserRepository>(
          instanceName: 'mainnetExchangeUserRepository',
        ),
        testnetExchangeUserRepository: locator<ExchangeUserRepository>(
          instanceName: 'testnetExchangeUserRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    // The native controller and session lifetime belong to one auth view.
    locator.registerFactoryParam<
      CompleteExchangeAuthenticationUsecase,
      Future<Object> Function(String),
      ({bool isTestnet, bool Function() isOpen})
    >(
      (evaluateJavaScript, session) => CompleteExchangeAuthenticationUsecase(
        authRepository: ExchangeAuthRepositoryImpl(
          datasource: ExchangeWebAuthDatasource(
            isTestnet: session.isTestnet,
            evaluateJavaScript: evaluateJavaScript,
            isOpen: session.isOpen,
          ),
        ),
        apiKeyRepository: locator<ExchangeApiKeyRepository>(),
        isTestnet: session.isTestnet,
      ),
    );

    locator.registerFactory<ClearExchangeSessionUsecase>(
      () => ClearExchangeSessionUsecase(
        exchangeApiKeyRepository: locator<ExchangeApiKeyRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        clearCookies: () => WebviewCookieManager().clearCookies(),
      ),
    );

    locator.registerFactory<RequestExchangeAccountDeletionUsecase>(
      () => RequestExchangeAccountDeletionUsecase(
        sendSupportChatMessageUsecase: locator<SendSupportChatMessageUsecase>(),
      ),
    );

    locator.registerFactory<WatchExchangeNotificationsUsecase>(
      () => WatchExchangeNotificationsUsecase(
        exchangeNotificationRepository:
            locator<ExchangeNotificationRepository>(),
      ),
    );
  }

  static void registerBlocs(GetIt locator) {
    locator.registerLazySingleton<ExchangeCubit>(
      () => ExchangeCubit(
        getExchangeAccountUsecase: locator<GetExchangeAccountUsecase>(),
        saveExchangePreferencesUsecase:
            locator<SaveExchangePreferencesUsecase>(),
        clearExchangeSessionUsecase: locator<ClearExchangeSessionUsecase>(),
        getExchangeAnnouncementsUsecase:
            locator<GetExchangeAnnouncementsUsecase>(),
        requestExchangeAccountDeletionUsecase:
            locator<RequestExchangeAccountDeletionUsecase>(),
        watchExchangeNotificationsUsecase:
            locator<WatchExchangeNotificationsUsecase>(),
      ),
    );
  }
}

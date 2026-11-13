import 'package:bb_mobile/features/exchange/data/exchange_access_repository_impl.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_access_repository.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/resolve_exchange_access_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/enable_exchange_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/sign_out_exchange_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/expire_exchange_session_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/watch_exchange_access_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/guard_exchange_trading_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/delete_exchange_account_usecase.dart';
import 'dart:io';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_notification_repository.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/features/exchange/data/exchange_account_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart'
    as settings_contract;
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_web_settings_usecase.dart';
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
    Future<bool> platformAllowed() async =>
        !Platform.isIOS ||
        ((await locator<settings_contract.SettingsRepository>().fetch())
                .isSuperuser ??
            false);
    locator.registerLazySingleton<ExchangeAccessRepository>(
      () => ExchangeAccessRepositoryImpl(
        apiKeyRepository: locator<ExchangeApiKeyRepository>(),
        readEnvironment: () async =>
            (await locator<settings_contract.SettingsRepository>().fetch())
                .environment
                .isTestnet,
        platformAllowed: platformAllowed,
        disconnectNotifications: () async =>
            locator<ExchangeNotificationRepository>().disconnect(),
        clearCookies: () => WebviewCookieManager().clearCookies(),
      ),
    );
    locator.registerFactory<ResolveExchangeAccessUsecase>(
      () => ResolveExchangeAccessUsecase(locator<ExchangeAccessRepository>()),
    );
    locator.registerFactory<EnableExchangeUsecase>(
      () => EnableExchangeUsecase(locator<ExchangeAccessRepository>()),
    );
    locator.registerFactory<SignOutExchangeUsecase>(
      () => SignOutExchangeUsecase(locator<ExchangeAccessRepository>()),
    );
    locator.registerFactory<ExpireExchangeSessionUsecase>(
      () => ExpireExchangeSessionUsecase(locator<ExchangeAccessRepository>()),
    );
    locator.registerFactory<WatchExchangeAccessUsecase>(
      () => WatchExchangeAccessUsecase(locator<ExchangeAccessRepository>()),
    );
    locator.registerFactory<GuardExchangeTradingUsecase>(
      () => GuardExchangeTradingUsecase(
        locator<ExchangeAccessRepository>(),
        platformAllowed,
      ),
    );
    registerUsecases(locator);
    registerBlocs(locator);
    locator.registerLazySingleton<ExchangeFacade>(
      () => ExchangeFacade(
        getExchangeAccountUsecase: locator<GetExchangeAccountUsecase>(),
        saveExchangePreferencesUsecase:
            locator<SaveExchangePreferencesUsecase>(),
        resolveAccess: locator<ResolveExchangeAccessUsecase>(),
        enable: locator<EnableExchangeUsecase>(),
        signOut: locator<SignOutExchangeUsecase>(),
        watchAccess: locator<WatchExchangeAccessUsecase>(),
        tradingGuard: locator<GuardExchangeTradingUsecase>(),
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
        settingsRepository: locator<SettingsRepository>(),
        access: locator<ExchangeAccessRepository>(),
        expire: locator<ExpireExchangeSessionUsecase>(),
        mainnetAccountRepository: ExchangeAccountRepositoryImpl(
          locator<BullbitcoinApiDatasource>(
            instanceName: 'mainnetExchangeApiDatasource',
          ),
        ),
        testnetAccountRepository: ExchangeAccountRepositoryImpl(
          locator<BullbitcoinApiDatasource>(
            instanceName: 'testnetExchangeApiDatasource',
          ),
        ),
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
        access: locator<ExchangeAccessRepository>(),
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
        access: locator<ExchangeAccessRepository>(),
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
        access: locator<ExchangeAccessRepository>(),
        isTestnet: session.isTestnet,
      ),
    );

    locator.registerFactory<RequestExchangeAccountDeletionUsecase>(
      () => RequestExchangeAccountDeletionUsecase(
        sendSupportChatMessageUsecase: locator<SendSupportChatMessageUsecase>(),
      ),
    );

    locator.registerFactory<DeleteExchangeAccountUsecase>(
      () => DeleteExchangeAccountUsecase(
        locator<RequestExchangeAccountDeletionUsecase>(),
        locator<SignOutExchangeUsecase>(),
        locator<ExchangeAccessRepository>(),
      ),
    );
    locator.registerFactory<WatchExchangeNotificationsUsecase>(
      () => WatchExchangeNotificationsUsecase(
        access: locator<ExchangeAccessRepository>(),
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
        getExchangeAnnouncementsUsecase:
            locator<GetExchangeAnnouncementsUsecase>(),
        deleteAccount: locator<DeleteExchangeAccountUsecase>(),
        watchAccess: locator<WatchExchangeAccessUsecase>(),
        watchExchangeNotificationsUsecase:
            locator<WatchExchangeNotificationsUsecase>(),
      ),
    );
  }
}

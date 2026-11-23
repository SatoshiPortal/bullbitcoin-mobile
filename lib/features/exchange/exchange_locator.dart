import 'package:exchange/setup.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/resolve_exchange_access_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/enable_exchange_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/sign_out_exchange_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/expire_exchange_session_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/watch_exchange_access_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/guard_exchange_trading_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/delete_exchange_account_usecase.dart';

import 'dart:io';

import 'package:preferences/preferences.dart';
import 'package:preferences/preferences.dart' as settings_contract;
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
import 'package:exchange/exchange.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ExchangeLocator {
  static void setup(GetIt locator, {ExchangePlatform? platform}) {
    final activePlatform =
        platform ??
        (Platform.isIOS ? ExchangePlatform.ios : ExchangePlatform.other);
    Future<bool> platformAllowed() async {
      if (ExchangeAvailability.platformAllowed(activePlatform)) return true;
      final isSuperuser = switch (await locator<Preferences>().fetch()) {
        Ok(:final value) => value.isSuperuser == true,
        Err() => false,
      };
      return ExchangeAvailability.platformAllowed(
        activePlatform,
        isSuperuser: isSuperuser,
      );
    }

    locator.registerLazySingleton<ExchangeAccessLifecycle>(
      () => ExchangeAccessLifecycle.open(
        apiKeyRepository: locator<ExchangeCredentials>(),
        readEnvironment: () async =>
            ((await locator<settings_contract.Preferences>().fetch()).fold(
              (value) => value,
              (failure) => throw Exception('Preferences read failed'),
            )).environment.requireHistoricalTestnet(),
        platformAllowed: platformAllowed,
        disconnectNotifications: () async =>
            locator<Exchange>().disconnectNotifications(),
        clearCookies: () async {
          await WebViewCookieManager().clearCookies();
        },
        readPreference: () async => (await SharedPreferences.getInstance()).get(
          ExchangeAccessLifecycle.preferenceKey,
        ),
        writePreference: (value) async =>
            (await SharedPreferences.getInstance()).setString(
              ExchangeAccessLifecycle.preferenceKey,
              value,
            ),
      ),
    );
    locator.registerFactory<ResolveExchangeAccessUsecase>(
      () => ResolveExchangeAccessUsecase(locator<ExchangeAccessLifecycle>()),
    );
    locator.registerFactory<EnableExchangeUsecase>(
      () => EnableExchangeUsecase(locator<ExchangeAccessLifecycle>()),
    );
    locator.registerFactory<SignOutExchangeUsecase>(
      () => SignOutExchangeUsecase(locator<ExchangeAccessLifecycle>()),
    );
    locator.registerFactory<ExpireExchangeSessionUsecase>(
      () => ExpireExchangeSessionUsecase(locator<ExchangeAccessLifecycle>()),
    );
    locator.registerFactory<WatchExchangeAccessUsecase>(
      () => WatchExchangeAccessUsecase(locator<ExchangeAccessLifecycle>()),
    );
    locator.registerFactory<GuardExchangeTradingUsecase>(
      () => GuardExchangeTradingUsecase(
        locator<ExchangeAccessLifecycle>(),
        platformAllowed,
      ),
    );
    registerUsecases(locator);
    registerBlocs(locator);
    locator.registerLazySingleton<ExchangeFacade>(
      () => ExchangeFacade(
        getExchangeWebSettingsUsecase: locator<GetExchangeWebSettingsUsecase>(),
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
        preferences:
            locator<settings_contract.ExchangeTestnetBasicAuthPreferences>(),
      ),
    );
    locator.registerFactory<GetExchangeAccountUsecase>(
      () => GetExchangeAccountUsecase(
        settingsRepository: locator<Preferences>(),
        access: locator<ExchangeAccessLifecycle>(),
        expire: locator<ExpireExchangeSessionUsecase>(),
        exchange: locator<Exchange>(),
      ),
    );

    locator.registerFactory<SaveExchangePreferencesUsecase>(
      () => SaveExchangePreferencesUsecase(
        exchange: locator<Exchange>(),
        settingsRepository: locator<Preferences>(),
        access: locator<ExchangeAccessLifecycle>(),
      ),
    );

    locator.registerFactory<GetExchangeAnnouncementsUsecase>(
      () => GetExchangeAnnouncementsUsecase(
        exchange: locator<Exchange>(),
        settingsRepository: locator<Preferences>(),
        access: locator<ExchangeAccessLifecycle>(),
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
        access: locator<ExchangeAccessLifecycle>(),
        isTestnet: session.isTestnet,
      ),
    );

    locator.registerFactory<RequestExchangeAccountDeletionUsecase>(
      () => RequestExchangeAccountDeletionUsecase(
        settingsRepository: locator<settings_contract.Preferences>(),
        exchange: locator<Exchange>(),
      ),
    );

    locator.registerFactory<DeleteExchangeAccountUsecase>(
      () => DeleteExchangeAccountUsecase(
        locator<RequestExchangeAccountDeletionUsecase>(),
        locator<SignOutExchangeUsecase>(),
        locator<ExchangeAccessLifecycle>(),
      ),
    );
    locator.registerFactory<WatchExchangeNotificationsUsecase>(
      () => WatchExchangeNotificationsUsecase(
        access: locator<ExchangeAccessLifecycle>(),
        settingsRepository: locator<settings_contract.Preferences>(),
        exchange: locator<Exchange>(),
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
        enableAccess: locator<EnableExchangeUsecase>(),
        resolveAccess: locator<ResolveExchangeAccessUsecase>(),
        signOut: locator<SignOutExchangeUsecase>(),
        watchAccess: locator<WatchExchangeAccessUsecase>(),
        watchExchangeNotificationsUsecase:
            locator<WatchExchangeNotificationsUsecase>(),
      ),
    );
  }
}

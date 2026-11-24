import 'package:exchange/setup.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/resolve_exchange_access_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/enable_exchange_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/sign_out_exchange_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/watch_exchange_access_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/guard_exchange_trading_usecase.dart';

import 'dart:io';

import 'package:preferences/preferences.dart';
import 'package:preferences/preferences.dart' as settings_contract;
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
    locator.registerFactory<WatchExchangeAccessUsecase>(
      () => WatchExchangeAccessUsecase(locator<ExchangeAccessLifecycle>()),
    );
    locator.registerFactory<GuardExchangeTradingUsecase>(
      () => GuardExchangeTradingUsecase(
        locator<ExchangeAccessLifecycle>(),
        platformAllowed,
      ),
    );
    locator.registerLazySingleton<ExchangeFacade>(
      () => ExchangeFacade(
        loadWebPreferences: () => locator<Exchange>().loadWebPreferences(),
        loadAccount: () => locator<Exchange>().loadCurrentAccount(),
        saveAccountPreferences:
            ({language, currency, emailNotificationsEnabled}) =>
                locator<Exchange>().updateCurrentPreferences(
                  language: language,
                  currency: currency,
                  emailNotificationsEnabled: emailNotificationsEnabled,
                ),
        resolveAccess: locator<ResolveExchangeAccessUsecase>(),
        enable: locator<EnableExchangeUsecase>(),
        signOut: locator<SignOutExchangeUsecase>(),
        watchAccess: locator<WatchExchangeAccessUsecase>(),
        tradingGuard: locator<GuardExchangeTradingUsecase>(),
      ),
    );
  }
}

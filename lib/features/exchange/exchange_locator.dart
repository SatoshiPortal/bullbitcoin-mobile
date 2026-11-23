import 'package:exchange/setup.dart';

import 'dart:io';

import 'package:preferences/preferences.dart';
import 'package:preferences/preferences.dart' as settings_contract;
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart' show Err, Ok;
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
  }
}

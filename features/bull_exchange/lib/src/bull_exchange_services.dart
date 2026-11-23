import 'dart:io';

import 'package:exchange/exchange.dart';
import 'package:exchange/setup.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show ExchangeKeychain;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Opens the Exchange capability with its session, credentials and platform
/// policy. Storage, WebView cookies and the platform belong to this feature;
/// the host supplies only the keychain and the preferences.
abstract final class BullExchangeServices {
  static Exchange open({
    required ExchangeKeychain keychain,
    required Preferences preferences,
    ExchangePlatform? platform,
  }) {
    final credentials = ExchangeCredentials.open(keychain);
    final activePlatform =
        platform ??
        (Platform.isIOS ? ExchangePlatform.ios : ExchangePlatform.other);
    // The lifecycle and the capability call each other only after opening.
    late final Exchange exchange;
    final access = ExchangeAccessLifecycle.open(
      apiKeyRepository: credentials,
      readEnvironment: () async => ((await preferences.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      )).environment.requireHistoricalTestnet(),
      platformAllowed: () =>
          _platformAllowed(activePlatform, preferences: preferences),
      disconnectNotifications: () async => exchange.disconnectNotifications(),
      clearCookies: () async {
        await WebViewCookieManager().clearCookies();
      },
      readPreference: () async => (await SharedPreferences.getInstance()).get(
        ExchangeAccessLifecycle.preferenceKey,
      ),
      writePreference: (value) async => (await SharedPreferences.getInstance())
          .setString(ExchangeAccessLifecycle.preferenceKey, value),
    );
    exchange = Exchange.open(
      mainnetEndpoint: Uri.parse(ExchangeDefaults.bbApiUrl),
      testnetEndpoint: Uri.parse(ExchangeDefaults.bbApiTestUrl),
      paymentReturnUrl: Uri.parse(ExchangeDefaults.bbAppUrl),
      access: access,
      sessionPreferences: preferences,
      webAuthEndpoints: (
        mainnet: Uri.parse(ExchangeDefaults.bbAuthUrl),
        testnet: Uri.parse(ExchangeDefaults.bbAuthTestUrl),
      ),
      kyc: (
        mainnetUrl: Uri.parse(ExchangeDefaults.bbKycUrl),
        testnetUrl: Uri.parse(ExchangeDefaults.bbKycTestUrl),
        preferences: preferences,
      ),
      readSession: () => readLegacyExchangeSession(
        preferences: preferences,
        readSession: () => access.session,
        readKey: credentials.readActiveApiKey,
      ),
      notifications: (
        readEnvironment: () => readLegacyExchangeEnvironment(preferences),
        readKey: ({required isTestnet}) =>
            credentials.readActiveApiKey(isTestnet: isTestnet),
      ),
    );
    return exchange;
  }

  /// iOS allows trading only to superusers; an unreadable preference hides it.
  static Future<bool> _platformAllowed(
    ExchangePlatform platform, {
    required Preferences preferences,
  }) async {
    if (ExchangeAvailability.platformAllowed(platform)) return true;
    final isSuperuser = switch (await preferences.fetch()) {
      Ok(:final value) => value.isSuperuser == true,
      Err() => false,
    };
    return ExchangeAvailability.platformAllowed(
      platform,
      isSuperuser: isSuperuser,
    );
  }
}

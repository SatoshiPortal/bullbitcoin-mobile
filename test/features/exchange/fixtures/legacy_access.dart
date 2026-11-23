import 'package:exchange/setup.dart';
import 'package:shared_preferences/shared_preferences.dart';

ExchangeAccessLifecycle legacyAccessForTesting({
  required ExchangeCredentials apiKeyRepository,
  required Future<bool> Function() readEnvironment,
  required Future<bool> Function() platformAllowed,
  required Future<void> Function() disconnectNotifications,
  required Future<void> Function() clearCookies,
  Future<bool> Function(String)? writePreference,
}) => ExchangeAccessLifecycle.open(
  apiKeyRepository: apiKeyRepository,
  readEnvironment: readEnvironment,
  platformAllowed: platformAllowed,
  disconnectNotifications: disconnectNotifications,
  clearCookies: clearCookies,
  readPreference: () async => (await SharedPreferences.getInstance()).get(
    ExchangeAccessLifecycle.preferenceKey,
  ),
  writePreference:
      writePreference ??
      (value) async => (await SharedPreferences.getInstance()).setString(
        ExchangeAccessLifecycle.preferenceKey,
        value,
      ),
);

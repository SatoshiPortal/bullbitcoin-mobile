import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:network/setup.dart';
import 'package:primitives/primitives.dart';

class SettingsNetworkBindings {
  static Future<NetworkEnv> readEnvironment(
    SettingsRepository settings,
  ) async => (await settings.fetch()).environment.networkEnv;

  static Future<bool> saveTorProxy(
    SettingsRepository settings, {
    required bool enabled,
    required int port,
  }) async =>
      switch (await settings.setTorProxy(enabled: enabled, port: port)) {
        Ok() => true,
        Err() => false,
      };

  static Future<TorPreferences> readTorPreferences(
    SettingsRepository settings,
  ) async {
    final value = await settings.fetch();
    return (
      useTorProxy: value.useTorProxy,
      torProxyPort: value.torProxyPort,
      torTransportMode: value.torTransportMode,
      lastSuccessfulTorTransport: value.lastSuccessfulTorTransport,
    );
  }
}

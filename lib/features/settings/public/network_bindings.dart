import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:get_it/get_it.dart';
import 'package:network/network.dart';
import 'package:primitives/primitives.dart';

class SettingsNetworkBindings {
  static void setup(GetIt locator) {
    ElectrumSettingsLocator.setup(locator);
    TorSettingsLocator.setup(
      locator,
      readPreferences: () => readTorPreferences(locator<SettingsRepository>()),
      saveMode: (mode) =>
          locator<SettingsRepository>().setTorTransportMode(mode),
      saveProxy: ({required enabled, required port}) async {
        return switch (await locator<SettingsRepository>().setTorProxy(
          enabled: enabled,
          port: port,
        )) {
          Ok() => true,
          Err() => false,
        };
      },
    );
  }

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

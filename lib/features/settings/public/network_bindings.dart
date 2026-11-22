import 'package:preferences/preferences.dart';
import 'package:network/setup.dart';
import 'package:primitives/primitives.dart';

class SettingsNetworkBindings {
  static Future<NetworkEnv> readEnvironment(Preferences settings) async =>
      ((await settings.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      )).environment.networkEnv;

  static Future<bool> saveTorProxy(
    Preferences settings, {
    required bool enabled,
    required int port,
  }) async =>
      switch (await settings.setTorProxy(enabled: enabled, port: port)) {
        Ok() => true,
        Err() => false,
      };

  static Future<TorPreferences> readTorPreferences(Preferences settings) async {
    final value = (await settings.fetch()).fold(
      (value) => value,
      (failure) => throw Exception('Preferences read failed'),
    );
    return (
      useTorProxy: value.useTorProxy,
      torProxyPort: value.torProxyPort,
      torTransportMode: value.torTransportMode,
      lastSuccessfulTorTransport: value.lastSuccessfulTorTransport,
    );
  }
}

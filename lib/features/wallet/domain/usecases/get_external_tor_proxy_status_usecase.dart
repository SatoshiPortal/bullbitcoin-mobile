import 'dart:io';

import 'package:preferences/preferences.dart';
import 'package:bull_tor/tor.dart';

enum ExternalTorProxyStatus { disabled, available, unavailable }

class GetExternalTorProxyStatusUsecase {
  final TorProxyPreferencesReader _settingsRepository;
  final Tor _tor;

  const GetExternalTorProxyStatusUsecase(this._settingsRepository, this._tor);

  Future<ExternalTorProxyStatus> execute() async {
    try {
      final settings = (await _settingsRepository.readTorProxyPreferences())
          .fold(
            (value) => value,
            (failure) => throw Exception('Preferences read failed'),
          );
      if (!settings.useTorProxy) return ExternalTorProxyStatus.disabled;
      final TorProxyEndpoint endpoint;
      try {
        endpoint = TorProxyEndpoint(
          host: InternetAddress.loopbackIPv4.address,
          port: settings.torProxyPort,
        );
      } on ArgumentError {
        return ExternalTorProxyStatus.unavailable;
      }
      return switch (await _tor.external.verify(endpoint)) {
        TorReady() => ExternalTorProxyStatus.available,
        _ => ExternalTorProxyStatus.unavailable,
      };
    } on Exception {
      return ExternalTorProxyStatus.unavailable;
    }
  }
}

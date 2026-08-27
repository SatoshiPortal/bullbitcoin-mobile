import 'dart:io';

import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bull_tor/tor.dart';

enum ExternalTorProxyStatus { disabled, available, unavailable }

class GetExternalTorProxyStatusUsecase {
  final SettingsRepository _settingsRepository;
  final Tor _tor;

  const GetExternalTorProxyStatusUsecase(this._settingsRepository, this._tor);

  Future<ExternalTorProxyStatus> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
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

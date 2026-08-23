import 'dart:io';

import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bull_tor/tor.dart';

enum ExternalTorProxyStatus { disabled, available, unavailable }

class GetExternalTorProxyStatusUsecase {
  GetExternalTorProxyStatusUsecase(
    this._settingsRepository,
    this._verifyExternalTorUsecase,
  );

  final SettingsRepository _settingsRepository;
  final VerifyExternalTorUsecase _verifyExternalTorUsecase;

  Future<ExternalTorProxyStatus> execute() async {
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

    final connection = await _verifyExternalTorUsecase.execute(endpoint);
    return connection is TorReady
        ? ExternalTorProxyStatus.available
        : ExternalTorProxyStatus.unavailable;
  }
}

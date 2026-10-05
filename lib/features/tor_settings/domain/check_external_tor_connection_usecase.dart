import 'dart:io';

import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bull_tor/tor.dart';

final class CheckExternalTorConnectionUsecase {
  final GetSettingsUsecase _getSettingsUsecase;
  final Tor _tor;

  const CheckExternalTorConnectionUsecase(this._getSettingsUsecase, this._tor);

  Future<TorConnectionState> execute() async {
    try {
      final settings = await _getSettingsUsecase.execute();
      if (!settings.useTorProxy) {
        return const TorUnavailable(
          source: TorSource.external,
          failure: TorExternalProxyUnavailableFailure(),
        );
      }
      final TorProxyEndpoint endpoint;
      try {
        endpoint = TorProxyEndpoint(
          host: InternetAddress.loopbackIPv4.address,
          port: settings.torProxyPort,
        );
      } on ArgumentError {
        return const TorUnavailable(
          source: TorSource.external,
          failure: TorExternalProxyUnavailableFailure(),
        );
      }
      return _tor.external.verify(endpoint);
    } on Exception {
      return const TorUnavailable(
        source: TorSource.external,
        failure: TorExternalProxyUnavailableFailure(),
      );
    }
  }
}

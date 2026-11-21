import 'tor_preferences.dart';

import 'dart:io';

import 'package:bull_tor/tor.dart';

final class CheckExternalTorConnectionUsecase {
  final ReadTorPreferences _readPreferences;
  final Tor _tor;

  const CheckExternalTorConnectionUsecase(this._readPreferences, this._tor);

  Future<TorConnectionState> execute() async {
    try {
      final settings = await _readPreferences();
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
      return await _tor.external.verify(endpoint);
    } on Exception {
      return const TorUnavailable(
        source: TorSource.external,
        failure: TorExternalProxyUnavailableFailure(),
      );
    }
  }
}

import 'dart:io';

import 'package:bull_tor/tor.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

final class CheckExternalTorConnectionUsecase {
  final TorProxyPreferencesReader _preferences;
  final Tor _tor;

  const CheckExternalTorConnectionUsecase(this._preferences, this._tor);

  Future<TorConnectionState> execute() async {
    try {
      final result = await _preferences.readTorProxyPreferences();
      if (result case Ok(value: final settings) when settings.useTorProxy) {
        final TorProxyEndpoint endpoint;
        try {
          endpoint = TorProxyEndpoint(
            host: InternetAddress.loopbackIPv4.address,
            port: settings.torProxyPort,
          );
        } on ArgumentError {
          return _unavailable;
        }
        return await _tor.external.verify(endpoint);
      }
      return _unavailable;
    } on Exception {
      return _unavailable;
    }
  }

  static const _unavailable = TorUnavailable(
    source: TorSource.external,
    failure: TorExternalProxyUnavailableFailure(),
  );
}

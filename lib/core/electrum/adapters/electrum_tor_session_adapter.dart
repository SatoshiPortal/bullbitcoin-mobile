import 'package:bb_mobile/core/electrum/domain/ports/electrum_tor_session_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_url.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bull_tor/tor.dart';

final class ElectrumTorSessionAdapter implements ElectrumTorSessionPort {
  final Tor Function() _tor;

  const ElectrumTorSessionAdapter(this._tor);

  @override
  Future<ElectrumTorRoute?> open({
    required ElectrumServerNetwork network,
    required String serverUrl,
    required bool isCustom,
    required bool externalProxyEnabled,
    required int externalProxyPort,
  }) async {
    if (network.isLiquid) return null;

    if (!isCustom || !ElectrumServerUrl(serverUrl).isOnion) return null;

    if (externalProxyEnabled) {
      final TorProxyEndpoint endpoint;
      try {
        endpoint = TorProxyEndpoint(
          host: '127.0.0.1',
          port: externalProxyPort,
        );
      } on ArgumentError {
        throw OnionServerWithoutTorException(serverUrl);
      }
      return switch (await _tor().external.verify(endpoint)) {
        TorReady(:final route) => ElectrumTorRoute(route.endpoint, () async {}),
        TorUnavailable() => throw OnionServerWithoutTorException(serverUrl),
        _ => throw OnionServerWithoutTorException(serverUrl),
      };
    }

    final session = await _tor().embedded.sessions.open();
    return ElectrumTorRoute(session.endpoint, session.close);
  }
}

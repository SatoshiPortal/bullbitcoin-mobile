import 'dart:io';

import 'package:bb_mobile/core/electrum/domain/ports/electrum_tor_session_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_url.dart';
import 'package:tor/tor.dart';

final class ElectrumTorSessionAdapter implements ElectrumTorSessionPort {
  final Tor Function() _tor;

  const ElectrumTorSessionAdapter(this._tor);

  @override
  Future<ElectrumTorRoute?> open({
    required ElectrumServerNetwork network,
    required String serverUrl,
    required bool externalProxyEnabled,
    required int externalProxyPort,
  }) async {
    if (network.isLiquid || !ElectrumServerUrl(serverUrl).isOnion) return null;

    if (externalProxyEnabled) {
      return ElectrumTorRoute(
        TorProxyEndpoint(
          host: InternetAddress.loopbackIPv4.address,
          port: externalProxyPort,
        ),
        () async {},
      );
    }

    final session = await _tor().embedded.sessions.open();
    return ElectrumTorRoute(session.endpoint, session.close);
  }
}

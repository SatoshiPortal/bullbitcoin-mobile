import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bull_tor/tor.dart';

final class ElectrumTorRoute {
  final TorProxyEndpoint endpoint;
  final Future<void> Function() _onClose;
  Future<void>? _closing;

  ElectrumTorRoute(this.endpoint, this._onClose);

  Future<void> close() => _closing ??= _onClose();
}

/// Opens the proxy route for one Electrum server attempt.
abstract interface class ElectrumTorSessionPort {
  Future<ElectrumTorRoute?> open({
    required ElectrumServerNetwork network,
    required String serverUrl,
    required bool externalProxyEnabled,
    required int externalProxyPort,
  });
}

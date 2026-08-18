import 'package:bull_tor/tor.dart';

final class MempoolTorRoute {
  final TorProxyEndpoint endpoint;
  final Future<void> Function() _onClose;
  Future<void>? _closing;

  MempoolTorRoute(this.endpoint, this._onClose);

  Future<void> close() => _closing ??= _onClose();
}

/// Opens an isolated Tor route for one Mempool onion validation.
abstract interface class MempoolTorSessionPort {
  Future<MempoolTorRoute?> open({required String serverUrl});
}

import '../electrum_server_network.dart';

/// Connection and sync options persisted for one Electrum network.
final class ElectrumOptions {
  static const int maxStopGap = 5000;
  static const int maxTimeout = 300;

  final int stopGap;
  final int timeout;
  final int retry;
  final bool validateDomain;
  final ElectrumServerNetwork network;
  final String? socks5;

  const ElectrumOptions({
    required this.stopGap,
    required this.timeout,
    required this.retry,
    required this.validateDomain,
    required this.network,
    this.socks5,
  });
}

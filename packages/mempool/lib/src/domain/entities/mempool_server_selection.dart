import 'mempool_server.dart';

/// The service's default and optional custom server for a single network.
class MempoolServerSelection {
  final MempoolServer defaultServer;
  final MempoolServer? customServer;

  const MempoolServerSelection({
    required this.defaultServer,
    required this.customServer,
  });
}

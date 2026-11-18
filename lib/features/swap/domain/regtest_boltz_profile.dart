import 'package:primitives/primitives.dart';

/// Swap service roles for the explicitly selected local regtest backend.
/// Host parsing and build configuration belong to the shared host profile.
final class RegtestBoltzProfile {
  final Uri api;
  final Uri webSocket;
  final Uri bitcoinExplorer;
  final Uri liquidExplorer;

  RegtestBoltzProfile._(String host)
    : api = Uri(scheme: 'http', host: host, port: 9001, path: '/v2'),
      webSocket = Uri(scheme: 'ws', host: host, port: 9004),
      bitcoinExplorer = Uri(scheme: 'http', host: host, port: 3000),
      liquidExplorer = Uri(scheme: 'http', host: host, port: 3001);

  static RegtestBoltzProfile? forNetwork(
    NetworkEnv environment, {
    String? host,
  }) {
    final profile = host == null
        ? RegtestHostProfile.forNetwork(environment)
        : RegtestHostProfile.forNetwork(environment, host: host);
    return profile == null ? null : RegtestBoltzProfile._(profile.host);
  }
}

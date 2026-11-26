import 'package:primitives/primitives.dart';

/// Swap service roles for the explicitly selected regtest backend.
/// Stack selection and validation belong to the shared regtest profile.
final class RegtestBoltzProfile {
  final Uri api;

  /// The websocket base; the stream client appends its `/ws` route.
  final Uri webSocket;
  final Uri bitcoinExplorer;
  final Uri liquidExplorer;

  RegtestBoltzProfile._({
    required this.api,
    required this.webSocket,
    required this.bitcoinExplorer,
    required this.liquidExplorer,
  });

  factory RegtestBoltzProfile._of(RegtestHostProfile profile) =>
      switch (profile) {
        LocalRegtestHost(:final host) => RegtestBoltzProfile._(
          api: Uri(scheme: 'http', host: host, port: 9001, path: '/v2'),
          webSocket: Uri(scheme: 'ws', host: host, port: 9004),
          bitcoinExplorer: Uri(scheme: 'http', host: host, port: 3000),
          liquidExplorer: Uri(scheme: 'http', host: host, port: 3001),
        ),
        HostedRegtestStack(:final endpoints) => RegtestBoltzProfile._(
          api: endpoints.boltzApi,
          webSocket: _webSocketBase(endpoints.boltzWebSocket),
          bitcoinExplorer: endpoints.esploraBitcoin,
          liquidExplorer: endpoints.esploraLiquid,
        ),
      };

  /// The shared profile guarantees the `/ws` route this strips.
  static Uri _webSocketBase(Uri stream) => stream.replace(
    path: stream.path.substring(0, stream.path.length - '/ws'.length),
  );

  static RegtestBoltzProfile? forNetwork(
    NetworkEnv environment, {
    String? host,
    RegtestHostedDefines? hosted,
  }) {
    final profile = RegtestHostProfile.forNetwork(
      environment,
      host: host ?? const String.fromEnvironment('BULL_REGTEST_HOST'),
      hosted: hosted ?? const RegtestHostedDefines(),
    );
    return profile == null ? null : RegtestBoltzProfile._of(profile);
  }
}

import 'package:bull_tor/tor.dart';
import 'package:primitives/primitives.dart';

/// Key-server configuration, constructed only for a regtest runtime.
///
/// A local stack serves a fixture onion name through its own SOCKS proxy; a
/// hosted stack publishes a real onion service reached over the embedded Tor.
final class RegtestRecoverBullProfile {
  final Uri server;

  /// The local stack's external SOCKS proxy; null routes through embedded Tor.
  final TorProxyEndpoint? endpoint;

  const RegtestRecoverBullProfile._(this.server, this.endpoint);

  factory RegtestRecoverBullProfile(RegtestHostProfile profile) =>
      switch (profile) {
        LocalRegtestHost(:final host) => RegtestRecoverBullProfile._(
          Uri.parse('http://regtest.recoverbull.onion:3000'),
          TorProxyEndpoint(host: host, port: 59051),
        ),
        HostedRegtestStack(:final endpoints) => RegtestRecoverBullProfile._(
          endpoints.recoverBull,
          null,
        ),
      };
}

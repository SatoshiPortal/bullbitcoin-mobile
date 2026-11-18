import 'package:bull_tor/tor.dart';
import 'package:primitives/primitives.dart';

/// Local key-server configuration, constructed only for a regtest runtime.
final class RegtestRecoverBullProfile {
  final RegtestHostProfile hostProfile;

  const RegtestRecoverBullProfile(this.hostProfile);

  Uri get server => Uri.parse('http://regtest.recoverbull.onion:3000');

  TorProxyEndpoint get endpoint =>
      TorProxyEndpoint(host: hostProfile.host, port: 59051);
}

import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Where the wallet talks to: the Ark server and the esplora chain source.
/// bark has no Electrum backend, so the chain source is always esplora.
@immutable
final class ArkServerConfig {
  final BitcoinNetwork network;
  final Uri serverUrl;
  final Uri esploraUrl;

  const ArkServerConfig({
    required this.network,
    required this.serverUrl,
    required this.esploraUrl,
  });

  /// Second's public signet deployment.
  factory ArkServerConfig.secondSignet() => ArkServerConfig(
    network: BitcoinNetwork.signet,
    serverUrl: Uri.parse('https://ark.signet.2nd.dev'),
    esploraUrl: Uri.parse('https://esplora.signet.2nd.dev'),
  );
}

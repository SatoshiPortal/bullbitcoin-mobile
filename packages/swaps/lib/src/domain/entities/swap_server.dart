import 'package:swaps/setup.dart';

/// The Boltz backend the swap engine talks to, in the engine's form: a bare
/// host path that it prefixes with https:// and wss://. An explicitly typed
/// `http://` is kept so a local or staging backend works on testnet; mainnet
/// never connects in plaintext (see [forEnvironment]).
class SwapServer {
  final String host;

  const SwapServer._(this.host);

  static const mainnetDefault = SwapServer._(
    SwapServiceDefaults.boltzMainnetUrlPath,
  );
  static const testnetDefault = SwapServer._(
    SwapServiceDefaults.boltzTestnetUrlPath,
  );

  static SwapServer defaultFor({required bool isTestnet}) =>
      isTestnet ? testnetDefault : mainnetDefault;

  bool get isPlaintext => host.startsWith('http://');

  /// Null when [input] is not a server address. Empty input is the
  /// network's default server. Permissive on purpose so IP:port, localhost
  /// and .onion hosts pass. A bare host gets Boltz's `/v2` API path; any
  /// other path must end in `/v2`.
  static SwapServer? parse(String input, {required bool isTestnet}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return defaultFor(isTestnet: isTestnet);
    if (trimmed.contains(RegExp(r'\s'))) return null;
    final isPlaintext = trimmed.startsWith('http://');
    final bare =
        (isPlaintext
                ? trimmed.substring('http://'.length)
                : trimmed.replaceFirst(RegExp('^(https|wss?)://'), ''))
            .replaceFirst(RegExp(r'/+$'), '');
    if (bare.isEmpty || bare.contains('://')) return null;
    final uri = Uri.tryParse('https://$bare');
    final host = uri?.host ?? '';
    if (!host.contains('.') && host != 'localhost') return null;
    final path = uri?.path ?? '';
    if (path.isNotEmpty && !path.endsWith('/v2')) return null;
    final withApi = path.isEmpty ? '$bare/v2' : bare;
    return SwapServer._(isPlaintext ? 'http://$withApi' : withApi);
  }

  SwapServer forEnvironment({required bool isTestnet}) =>
      isPlaintext && !isTestnet
      ? SwapServer._(host.substring('http://'.length))
      : this;

  @override
  bool operator ==(Object other) => other is SwapServer && other.host == host;

  @override
  int get hashCode => host.hashCode;

  @override
  String toString() => host;
}

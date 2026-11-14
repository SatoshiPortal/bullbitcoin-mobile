import 'package:bb_mobile/core/utils/constants.dart';

/// The Boltz backend the swap engine talks to, in the engine's form: a bare
/// host path that it prefixes with https:// and wss://. An explicitly typed
/// `http://` is kept so a local or staging backend works on testnet; mainnet
/// never connects in plaintext (see [forEnvironment]).
class SwapServer {
  final String host;

  const SwapServer._(this.host);

  static const mainnetDefault = SwapServer._(
    ApiServiceConstants.boltzMainnetUrlPath,
  );
  static const testnetDefault = SwapServer._(
    ApiServiceConstants.boltzTestnetUrlPath,
  );

  static SwapServer defaultFor({required bool isTestnet}) =>
      isTestnet ? testnetDefault : mainnetDefault;

  bool get isPlaintext => host.startsWith('http://');

  /// Null when [input] is not a server address. Empty input is the
  /// network's default server. Permissive on purpose so IP:port, localhost
  /// and .onion hosts pass.
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
    final host = Uri.tryParse('https://$bare')?.host ?? '';
    if (!host.contains('.') && host != 'localhost') return null;
    return SwapServer._(isPlaintext ? 'http://$bare' : bare);
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

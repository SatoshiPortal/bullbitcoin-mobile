import 'dart:convert';

import 'package:swaps/setup.dart';

/// HTTP basic authentication for a Boltz backend behind an access gate.
class SwapServerCredentials {
  final String username;
  final String password;

  const SwapServerCredentials({required this.username, required this.password});

  /// Null when both fields are empty: the backend takes no authentication.
  static SwapServerCredentials? of({
    required String username,
    required String password,
  }) => username.isEmpty && password.isEmpty
      ? null
      : SwapServerCredentials(username: username, password: password);

  /// Basic authentication ends the username at the first colon.
  bool get isValid => !username.contains(':');

  String get authorization =>
      'Basic ${base64Encode(utf8.encode('$username:$password'))}';

  /// The form an address carries them in. It must never be displayed or
  /// logged.
  String get userInfo =>
      '${Uri.encodeComponent(username)}:${Uri.encodeComponent(password)}';

  @override
  bool operator ==(Object other) =>
      other is SwapServerCredentials &&
      other.username == username &&
      other.password == password;

  @override
  int get hashCode => Object.hash(username, password);

  @override
  String toString() => 'SwapServerCredentials';
}

/// The Boltz backend the swap engine talks to, in the engine's form: a bare
/// host path that it prefixes with https:// and wss://. An explicitly typed
/// `http://` is kept so a local or staging backend works on testnet; mainnet
/// never connects in plaintext (see [forEnvironment]).
class SwapServer {
  final String host;
  final SwapServerCredentials? credentials;

  const SwapServer._(this.host, {this.credentials});

  static const mainnetDefault = SwapServer._(
    SwapServiceDefaults.boltzMainnetUrlPath,
  );
  static const testnetDefault = SwapServer._(
    SwapServiceDefaults.boltzTestnetUrlPath,
  );

  static SwapServer defaultFor({required bool isTestnet}) =>
      isTestnet ? testnetDefault : mainnetDefault;

  bool get isPlaintext => host.startsWith('http://');

  SwapServer withCredentials(SwapServerCredentials? credentials) =>
      SwapServer._(host, credentials: credentials);

  /// Null when [input] is not a server address. Empty input is the
  /// network's default server. Permissive on purpose so IP:port, localhost
  /// and .onion hosts pass. A bare host gets Boltz's `/v2` API path; any
  /// other path must end in `/v2`. Credentials typed into the address are
  /// refused: they belong in [credentials], which is stored as a secret.
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
    if (uri == null || uri.userInfo.isNotEmpty) return null;
    final host = uri.host;
    if (!host.contains('.') && host != 'localhost') return null;
    final path = uri.path;
    if (path.isNotEmpty && !path.endsWith('/v2')) return null;
    final withApi = path.isEmpty ? '$bare/v2' : bare;
    return SwapServer._(isPlaintext ? 'http://$withApi' : withApi);
  }

  SwapServer forEnvironment({required bool isTestnet}) =>
      isPlaintext && !isTestnet
      ? SwapServer._(host.substring('http://'.length), credentials: credentials)
      : this;

  @override
  bool operator ==(Object other) =>
      other is SwapServer &&
      other.host == host &&
      other.credentials == credentials;

  @override
  int get hashCode => Object.hash(host, credentials);

  @override
  String toString() => host;
}

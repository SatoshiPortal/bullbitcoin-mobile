/// An Electrum server address as configured.
///
/// Servers are stored with or without a scheme — Liquid entries usually omit
/// it and are always TLS — so anything that wants the host, the protocol, or
/// "is this an onion service" has to normalize first. That normalization used
/// to be copied into every caller; it lives here now.
///
/// Deliberately not self-validating: users type custom server URLs, and a
/// malformed one must still be displayable in the settings list. [uri] returns
/// null instead, so callers decide what an unusable address means to them.
final class ElectrumServerUrl {
  static const _defaultScheme = 'ssl';

  final String raw;

  const ElectrumServerUrl(this.raw);

  static bool isOnionHost(String host) =>
      host.endsWith('.onion') || host.endsWith('.onion.');

  String get _trimmed => raw.trim();

  bool get _hasScheme => _trimmed.contains('://');

  /// The configured scheme, or `ssl` when the address carries none.
  String get scheme =>
      _hasScheme ? _trimmed.split('://').first : _defaultScheme;

  /// Host and port without the scheme — what the user typed, and what the
  /// settings list shows.
  String get authority => _hasScheme ? _trimmed.split('://').last : _trimmed;

  /// Null when the address cannot be resolved to a host and port.
  Uri? get uri {
    final address = _trimmed;
    if (address.isEmpty) return null;

    final parsed = Uri.tryParse(
      _hasScheme ? address : '$_defaultScheme://$address',
    );
    if (parsed == null || parsed.host.isEmpty) return null;
    return parsed;
  }

  bool get isOnion {
    final host = uri?.host;
    return host != null && isOnionHost(host);
  }
}

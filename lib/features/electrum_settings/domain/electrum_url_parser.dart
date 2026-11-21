enum ElectrumUrlValidationError { empty, hasProtocol, invalidFormat }

class ElectrumUrlParser {
  static final _protocolPattern = RegExp('^([a-zA-Z]+)://');
  static final _addressPattern = RegExp(
    r'^(([a-zA-Z0-9.-]+):\d+)(?::([st]))?$',
  );

  /// Parses Electrum server URL and determines SSL setting based on suffix or defaults
  ///
  /// Supports the following formats:
  /// - `host:port:s` - SSL enabled (explicit)
  /// - `host:port:t` - SSL disabled/TCP (explicit)
  /// - `host:port` - Auto-detect based on host type:
  ///   - `.onion` addresses default to TCP (no SSL)
  ///   - Clearnet addresses default to SSL
  ///
  /// Throws ElectrumUrlValidationError if URL is invalid or incomplete
  ///
  /// [sslExplicit] is true when the SSL value was unambiguously determined
  /// (explicit `:s`/`:t` suffix, or `.onion` host). It is false for plain
  /// clearnet `host:port` where SSL is merely the default.
  static ({String cleanUrl, bool enableSsl, bool sslExplicit}) parse(
    String input,
  ) {
    final trimmedInput = input.trim();
    if (trimmedInput.isEmpty) throw ElectrumUrlValidationError.empty;

    if (_protocolPattern.hasMatch(trimmedInput)) {
      throw ElectrumUrlValidationError.hasProtocol;
    }

    final match = _addressPattern.firstMatch(trimmedInput);
    if ((match?.group(1), match?.group(2), match?.group(3)) case (
      final String cleanUrl,
      final String host,
      final suffix,
    )) {
      final isOnion = host.endsWith('.onion');
      return (
        cleanUrl: cleanUrl,
        enableSsl: suffix == null ? !isOnion : suffix == 's',
        sslExplicit: suffix != null || isOnion,
      );
    }

    throw ElectrumUrlValidationError.invalidFormat;
  }

  /// This is a non-throwing version of parse
  static ({String cleanUrl, bool enableSsl, bool sslExplicit})? tryParse(
    String input,
  ) {
    try {
      return parse(input);
    } catch (_) {
      return null;
    }
  }
}

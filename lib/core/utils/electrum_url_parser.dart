enum ElectrumUrlValidationError { empty, hasProtocol, invalidFormat }

class ElectrumUrlParser {
  /// Parses Electrum server URL and determines SSL setting based on suffix or defaults
  ///
  /// Supports the following formats:
  /// - `host:port:s` - SSL enabled (explicit)
  /// - `host:port:t` - SSL disabled/TCP (explicit)
  /// - `host:port` - Auto-detect based on host type:
  ///   - `.onion` addresses default to TCP (no SSL)
  ///   - Clearnet addresses default to SSL
  ///
  /// Returns null if URL is invalid or incomplete
  static ({String cleanUrl, bool enableSsl})? parse(String input) {
    final trimmedInput = input.trim();
    if (trimmedInput.isEmpty) return null;

    // Check for :s or :t suffix
    final suffixMatch = RegExp(
      r'^([a-zA-Z0-9.-]+):(\d+):(s|t)$',
    ).firstMatch(trimmedInput);

    if (suffixMatch != null) {
      final host = suffixMatch.group(1)!;
      final port = suffixMatch.group(2)!;
      final suffix = suffixMatch.group(3)!;
      final cleanUrl = '$host:$port';
      return (cleanUrl: cleanUrl, enableSsl: suffix == 's');
    }

    // Check if it's a valid host:port format (no suffix)
    final hostPortMatch = RegExp(
      r'^([a-zA-Z0-9.-]+):(\d+)$',
    ).firstMatch(trimmedInput);

    if (hostPortMatch != null) {
      final host = hostPortMatch.group(1)!;
      final isOnion = host.endsWith('.onion');
      // Default: .onion = tcp (false), clearnet = ssl (true)
      return (cleanUrl: trimmedInput, enableSsl: !isOnion);
    }

    return null;
  }

  /// Validates Electrum server URL format
  ///
  /// Accepts:
  /// - `host:port` format
  /// - Optional `:s` or `:t` suffix for SSL/TCP specification
  ///
  /// Rejects:
  /// - Protocol prefixes (ssl://, tcp://, etc.)
  /// - Invalid characters or format
  static ElectrumUrlValidationError? validate(String input) {
    final trimmedInput = input.trim();
    if (trimmedInput.isEmpty) return ElectrumUrlValidationError.empty;

    // Check for protocol prefix
    final protocolPattern = RegExp('^([a-zA-Z]+)://');
    if (protocolPattern.hasMatch(trimmedInput)) {
      return ElectrumUrlValidationError.hasProtocol;
    }

    // Validate host:port format (with optional :s or :t suffix)
    final hostPortPattern = RegExp(r'^[a-zA-Z0-9.-]+:\d+(:[st])?$');
    if (!hostPortPattern.hasMatch(trimmedInput)) {
      return ElectrumUrlValidationError.invalidFormat;
    }

    return null;
  }
}

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
  /// Throws ElectrumUrlValidationError if URL is invalid or incomplete
  static ({String cleanUrl, bool enableSsl}) parse(String input) {
    final trimmedInput = input.trim();
    if (trimmedInput.isEmpty) throw ElectrumUrlValidationError.empty;

    // Check for protocol prefix
    final protocolPattern = RegExp('^([a-zA-Z]+)://');
    if (protocolPattern.hasMatch(trimmedInput)) {
      throw ElectrumUrlValidationError.hasProtocol;
    }

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

    throw ElectrumUrlValidationError.invalidFormat;
  }

  /// This is a non-throwing version of parse
  static ({String cleanUrl, bool enableSsl})? tryParse(String input) {
    try {
      return parse(input);
    } catch (_) {
      return null;
    }
  }
}

enum MempoolUrlValidationError { empty, invalidFormat, hasPath, invalidDomain }

class MempoolUrlParser {
  /// Normalizes a mempool URL by removing protocol and trailing slashes
  static String normalizeUrl(String url) {
    return url
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/$'), '')
        .toLowerCase()
        .trim();
  }

  /// Parses and validates Mempool server URL and determines SSL setting
  ///
  /// SSL Detection:
  /// - If URL starts with `http://` -> SSL disabled
  /// - If URL starts with `https://` -> SSL enabled
  /// - If no protocol -> SSL enabled by default (users can override)
  ///
  /// Validation:
  /// - URL must not be empty
  /// - URL must not contain path components
  /// - URL must be a valid domain (contain a dot) or be localhost
  ///
  static ({String cleanUrl, bool enableSsl}) parse(String input) {
    final trimmedInput = input.trim();
    if (trimmedInput.isEmpty) throw MempoolUrlValidationError.empty;

    bool enableSsl = true;
    String urlWithoutProtocol = trimmedInput;

    if (trimmedInput.startsWith('https://')) {
      enableSsl = true;
      urlWithoutProtocol = trimmedInput.substring(8);
    } else if (trimmedInput.startsWith('http://')) {
      enableSsl = false;
      urlWithoutProtocol = trimmedInput.substring(7);
    }

    String cleanedUrl = urlWithoutProtocol.replaceFirst(RegExp(r'/$'), '');

    if (cleanedUrl.isEmpty) {
      throw MempoolUrlValidationError.invalidFormat;
    }

    if (cleanedUrl.contains('/')) {
      throw MempoolUrlValidationError.hasPath;
    }

    final hostname = cleanedUrl.split(':').first;
    if (!hostname.contains('.') && hostname != 'localhost') {
      throw MempoolUrlValidationError.invalidDomain;
    }

    return (cleanUrl: cleanedUrl, enableSsl: enableSsl);
  }

  static ({String cleanUrl, bool enableSsl})? tryParse(String input) {
    try {
      return parse(input);
    } catch (_) {
      return null;
    }
  }
}

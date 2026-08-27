enum MempoolUrlValidationError {
  empty,
  invalidFormat,
  hasPath,
  invalidDomain,
  hasUserInfo,
  hasQueryOrFragment,
  invalidPort,
}

class MempoolUrlParser {
  /// Normalizes a mempool URL by removing protocol and trailing slashes
  static String normalizeUrl(String url) {
    final parsed = parse(url);
    return parsed.cleanUrl;
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
    var url = trimmedInput;
    if (url.startsWith('https://')) {
      url = url.substring(8);
    } else if (url.startsWith('http://')) {
      enableSsl = false;
      url = url.substring(7);
    }
    final uri = Uri.parse('${enableSsl ? 'https' : 'http'}://$url');
    if (uri.host.isEmpty) {
      throw MempoolUrlValidationError.invalidFormat;
    }
    if (uri.userInfo.isNotEmpty) {
      throw MempoolUrlValidationError.hasUserInfo;
    }
    if (uri.query.isNotEmpty || uri.fragment.isNotEmpty) {
      throw MempoolUrlValidationError.hasQueryOrFragment;
    }
    if (uri.path.isNotEmpty && uri.path != '/') {
      throw MempoolUrlValidationError.hasPath;
    }
    if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
      throw MempoolUrlValidationError.invalidPort;
    }
    final hostname = uri.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
    if (!hostname.contains('.') && hostname != 'localhost') {
      throw MempoolUrlValidationError.invalidDomain;
    }
    return (
      cleanUrl: uri.hasPort ? '$hostname:${uri.port}' : hostname,
      enableSsl: enableSsl,
    );
  }

  static ({String cleanUrl, bool enableSsl})? tryParse(String input) {
    try {
      return parse(input);
    } catch (_) {
      return null;
    }
  }
}

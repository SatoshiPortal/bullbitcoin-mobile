/// Navigation policy for the authenticated Bull KYC flow.
class ExchangeKycNavigation {
  final Uri base;

  ExchangeKycNavigation(String url) : base = Uri.parse(url);

  Uri? resolve(String value) {
    final uri = Uri.tryParse(value);
    return uri == null ? null : base.resolveUri(uri);
  }

  bool isBull(Uri uri) =>
      base.scheme == 'https' &&
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      uri.host == base.host &&
      uri.port == base.port;

  bool allows(Uri uri) =>
      isBull(uri) &&
      ['/kyc', '/login', '/verification', '/bb-logo'].any(uri.path.contains);

  bool isIncode(Uri uri) =>
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      uri.port == 443 &&
      (uri.host == 'incodesmile.com' || uri.host.endsWith('.incodesmile.com'));

  // HttpAuthRequest exposes a host, but no scheme or port.
  bool allowsAuthentication(String host) =>
      base.scheme == 'https' && host == base.host;
}

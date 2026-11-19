/// Only the trusted HTTPS origin may remain in the authenticated WebView.
bool allowsSecurityNavigation(String baseUrl, String target) {
  final base = Uri.tryParse(baseUrl);
  final parsed = Uri.tryParse(target);
  if (base == null || parsed == null || base.scheme != 'https') return false;
  final uri = base.resolveUri(parsed);
  return uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      uri.host == base.host &&
      uri.port == base.port;
}

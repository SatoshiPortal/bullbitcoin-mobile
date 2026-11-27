Uri payjoinPeerRelay(String paymentUri) {
  final endpoint = Uri.parse(Uri.parse(paymentUri).queryParameters['pj'] ?? '');
  if (endpoint.scheme == 'https' &&
      endpoint.host == 'localhost' &&
      endpoint.port == 8040) {
    return Uri.parse('https://127.0.0.1:8041');
  }
  if (endpoint.scheme == 'https' &&
      endpoint.host == '127.0.0.1' &&
      endpoint.port == 8041) {
    return Uri.parse('https://localhost:8040');
  }
  throw const FormatException('Unexpected local Payjoin directory');
}

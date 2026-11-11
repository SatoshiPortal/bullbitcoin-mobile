import 'package:payjoin/payjoin.dart' as pdk;

/// No relay may carry a request: the directory cannot be read, or every
/// known server shares its domain. Nothing is sent.
class PayjoinRelayUnavailableException implements Exception {
  final String message;

  const PayjoinRelayUnavailableException(this.message);

  @override
  String toString() => 'PayjoinRelayUnavailableException: $message';
}

/// The servers allowed to relay requests for [payjoinUri]: every one of
/// [servers] outside the domain of the directory in its `pj` parameter. The
/// relay sees the user's IP and the directory sees the request, so one
/// operator running both would undo OHTTP.
///
/// Throws [PayjoinRelayUnavailableException] rather than returning an empty
/// list, so no caller can mistake "no safe relay" for "no constraint".
List<Uri> allowedRelays(String payjoinUri, {required List<Uri> servers}) {
  final directory = payjoinDirectoryOf(payjoinUri);
  if (directory == null) {
    throw const PayjoinRelayUnavailableException('no payjoin directory in URI');
  }
  return relaysOutsideDomainOf(directory, servers: servers);
}

/// Every one of [servers] outside the domain of [directory]. Used directly
/// only to reach a directory before any payjoin URI exists.
///
/// Throws [PayjoinRelayUnavailableException] when the directory's domain
/// cannot be read or no server lies outside it.
List<Uri> relaysOutsideDomainOf(Uri directory, {required List<Uri> servers}) {
  final directoryDomain = payjoinDomainOf(directory);
  if (directoryDomain == null) {
    throw const PayjoinRelayUnavailableException('unreadable directory host');
  }
  final relays = [
    for (final server in servers)
      if (payjoinDomainOf(server) != directoryDomain) server,
  ];
  if (relays.isEmpty) {
    throw const PayjoinRelayUnavailableException(
      'every server is on the directory domain',
    );
  }
  return relays;
}

/// The directory endpoint of [payjoinUri], read by the same BIP21 parser the
/// payjoin session uses; null when the URI is not a payjoin URI.
Uri? payjoinDirectoryOf(String payjoinUri) {
  try {
    final endpoint = pdk.Uri.parse(
      uri: payjoinUri,
    ).checkPjSupported().pjEndpoint();
    return Uri.parse(endpoint);
  } on Exception {
    return null;
  }
}

/// The host of [url] in one spelling: [Uri] already lowercases it and decodes
/// escapes, and a trailing dot names the same host. Null when there is none,
/// when a label is empty, or when it is not ASCII: an internationalized name
/// cannot be matched to its punycode form here, so it is refused.
String? payjoinHostOf(Uri url) {
  var host = url.host;
  if (host.endsWith('.')) host = host.substring(0, host.length - 1);
  if (host.isEmpty || host.contains('%') || host.split('.').contains('')) {
    return null;
  }
  return host;
}

/// The domain and TLD of [url], so that every subdomain of one operator
/// shares it: `pj.bullbitcoin.com` and `ohttp.bullbitcoin.com` both give
/// `bullbitcoin.com`. Under a multi-label public suffix such as `co.uk` this
/// groups more servers than needed, never fewer. An IP address is its own
/// domain.
String? payjoinDomainOf(Uri url) {
  final host = payjoinHostOf(url);
  if (host == null) return null;
  final labels = host.split('.');
  final isIp = host.contains(':') || labels.every(_isNumeric);
  if (isIp || labels.length <= 2) return host;
  return labels.sublist(labels.length - 2).join('.');
}

bool _isNumeric(String label) => int.tryParse(label) != null;

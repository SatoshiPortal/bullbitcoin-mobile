/// The relays this app publishes and reads vault descriptors on.
///
/// The list is a compiled-in constant. Nothing fetches it, no recovered backup
/// can add to it and no screen can edit it (plan 5.4): a relay URL that arrives
/// with the data it is supposed to authenticate is an attacker's choice of
/// destination, not a configuration.
///
/// A relay sees the backup identity, the timing of its events and, on a direct
/// connection, the device's address. Redundancy across five operators is about
/// availability, not anonymity, and acceptance by any of them is not a
/// retention promise.
abstract final class NostrDescriptorRelays {
  /// Five independent public operators. Each one was asked to store a
  /// disposable descriptor event on 2026-09-14 and to hand it back afterwards,
  /// and each did; a historical list is not evidence that a relay works today.
  ///
  /// Dropped after the same check: `relay.damus.io` and `relay.nostr.band` did
  /// not answer at all, `nostr.bitcoiner.social` and `nostr21.com` refused the
  /// event, and `nostr.wine` only accepts paying publishers. A relay that will
  /// not take the event cannot carry a backup, whatever its reputation.
  static const urls = [
    'wss://nos.lol',
    'wss://relay.primal.net',
    'wss://nostr.mom',
    'wss://offchain.pub',
    'wss://nostr.oxtr.dev',
  ];

  /// [urls], canonical and duplicate free, in the order they are written above.
  static final List<Uri> configured = List.unmodifiable(
    urls.map(parse).toSet(),
  );

  /// The canonical form of one relay URL.
  ///
  /// Canonicalising before comparison is what makes deduplication real:
  /// `WSS://Relay.Example:443/` and `wss://relay.example` are one relay, and
  /// publishing to both would count one acceptance twice.
  ///
  /// Throws [FormatException] for anything that is not a plain `wss` endpoint:
  /// a query, a fragment or user information all change where the connection
  /// goes or what it carries, and none of them belongs in a relay address.
  static Uri parse(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'wss' ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Invalid relay URL');
    }
    return Uri(
      scheme: 'wss',
      host: uri.host.toLowerCase(),
      port: uri.hasPort && uri.port != 443 ? uri.port : null,
      path: uri.path == '/' ? '' : uri.path,
    );
  }
}

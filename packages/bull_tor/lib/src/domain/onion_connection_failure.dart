/// Safe, destination-free causes for a failed SOCKS connection to an onion
/// service.
enum SocksConnectionFailureCause {
  tor('tor'),
  onionServiceUnreachable('onion_unreachable'),
  serviceRefused('refused'),

  /// SOCKS reply 0x06: the proxy gave up on the circuit. Unrelated to any
  /// client-side time budget a consumer enforces on top.
  ttlExpired('ttl_expired'),
  unknown('unknown');

  final String logValue;

  const SocksConnectionFailureCause(this.logValue);
}

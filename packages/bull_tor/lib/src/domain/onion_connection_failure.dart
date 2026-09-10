/// Safe, destination-free causes for a failed SOCKS connection to an onion
/// service.
enum SocksConnectionFailureCause {
  tor('tor'),
  onionServiceUnreachable('onion_unreachable'),
  serviceRefused('refused'),
  connectionBudgetExceeded('budget'),
  unknown('unknown');

  final String logValue;

  const SocksConnectionFailureCause(this.logValue);
}

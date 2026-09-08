import 'package:socks5_proxy/enums.dart';
import 'package:socks5_proxy/exceptions.dart';

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

/// Classifies only the SOCKS command exception carrying an RFC 1928 reply.
/// Every other exception remains [SocksConnectionFailureCause.unknown].
SocksConnectionFailureCause classifySocksConnectionFailure(Object error) {
  final code = switch (error) {
    SocksClientConnectionCommandFailedException(:final code) => code,
    _ => null,
  };

  return switch (code) {
    CommandReplyCode.networkUnreachable => SocksConnectionFailureCause.tor,
    CommandReplyCode.hostUnreachable =>
      SocksConnectionFailureCause.onionServiceUnreachable,
    CommandReplyCode.connectionRefused =>
      SocksConnectionFailureCause.serviceRefused,
    CommandReplyCode.ttlExpired =>
      SocksConnectionFailureCause.connectionBudgetExceeded,
    _ => SocksConnectionFailureCause.unknown,
  };
}

import 'package:socks5_proxy/enums.dart';
import 'package:socks5_proxy/exceptions.dart';

import '../domain/onion_connection_failure.dart';

/// Maps transport-specific SOCKS replies to the stable Bull cause contract.
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

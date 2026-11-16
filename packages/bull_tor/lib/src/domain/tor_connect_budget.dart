import 'entities/tor_transport.dart';

/// Time Tor gets to connect to a destination through a direct embedded listener, onion services included.
const torConnectBudget = Duration(seconds: 60);

/// The same budget through Snowflake, whose first onion contacts are slower.
///
/// On a censored network, 2 of 5 first contacts hit 60 seconds while Arti was still retrying its circuits inside the connect; a fresh attempt then succeeded within 37 seconds, so about 90 seconds in total.
const snowflakeConnectBudget = Duration(seconds: 90);

extension TorTransportConnectBudget on TorTransport {
  /// Time Tor gets to connect to a destination through this transport.
  Duration get connectBudget => switch (this) {
    TorTransport.direct => torConnectBudget,
    TorTransport.snowflake => snowflakeConnectBudget,
  };
}

/// Deadline for work that waits on a direct Tor connect: [torConnectBudget] plus 10%.
///
/// Callers derive their own timeouts from it so Tor's budget always expires first and its reason reaches them, instead of a bare timeout of their own.
final torConnectDeadline = torConnectBudget * 1.1;

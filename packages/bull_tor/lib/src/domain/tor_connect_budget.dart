import 'entities/tor_transport.dart';

/// Time Tor gets to connect to a destination through a direct embedded listener, onion services included.
///
/// The slowest first onion contact measured on devices took 64 seconds (1 of 33 attempts), so 90 seconds leaves a margin.
const torConnectBudget = Duration(seconds: 90);

/// The same budget through Snowflake, whose first onion contacts are slower.
///
/// Arti keeps retrying its circuits inside the connect: measured on devices, 5 of 29 first contacts took longer than 90 seconds and none longer than 200.
const snowflakeConnectBudget = Duration(seconds: 200);

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

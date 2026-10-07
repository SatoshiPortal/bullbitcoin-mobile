import 'tor_transport.dart';

/// Why automatic mode left one transport for the next.
enum TorFallbackReason {
  /// Arti's blockage looked like the network filtering Tor.
  censorship,

  /// The bootstrap stopped progressing for too long.
  stalled,

  /// The bootstrap kept going but ran out of time.
  timeout,
}

/// Automatic mode gave up on [from] and is now trying [to].
///
/// Published as an event, not as state: it tells the user once that the
/// connection is taking another road, and has nothing left to say afterwards.
final class TorTransportFallback {
  final TorTransport from;
  final TorTransport to;
  final TorFallbackReason reason;

  const TorTransportFallback({
    required this.from,
    required this.to,
    required this.reason,
  });
}

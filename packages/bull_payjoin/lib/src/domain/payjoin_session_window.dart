import 'package:bull_payjoin/src/domain/payjoin_policy.dart';

final class PayjoinSessionWindow {
  const PayjoinSessionWindow._();

  /// Time kept between the end of a payjoin negotiation and the order's
  /// deadline, for the fallback to reach the exchange while the order still
  /// accepts a payin.
  ///
  /// It covers the expiry being noticed (a directory poll in flight can hold
  /// it for up to its 35 s receive timeout), the original's broadcast over
  /// Tor, the exchange seeing it in its mempool, and clock skew. An initial
  /// policy, not a measured bound: on testnet the fallback landed three
  /// seconds after the order expired when the window ran to the deadline.
  static const fallbackReserve = Duration(seconds: 90);

  /// The negotiation window for an order due at [deadline], or null when too
  /// little time is left for a session and its fallback.
  static Duration? forOrderDeadline(DateTime deadline, {DateTime? now}) {
    final remaining =
        deadline.difference(now ?? DateTime.now()) - fallbackReserve;
    if (remaining < PayjoinPolicy.minimumSessionLifetime) return null;
    if (remaining > PayjoinPolicy.maximumSessionLifetime) {
      return PayjoinPolicy.maximumSessionLifetime;
    }
    return Duration(seconds: remaining.inSeconds);
  }
}

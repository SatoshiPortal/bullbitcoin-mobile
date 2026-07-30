import 'package:bb_mobile/core/utils/constants.dart';

/// How long a payjoin session may live when it is bound to an exchange order.
///
/// A standalone payjoin can afford the protocol-conventional 24 hours: if the
/// negotiation never completes, the original transaction is broadcast at expiry
/// and the payment still lands, late but valid.
///
/// An exchange payin cannot. The order carries a confirmation deadline of a few
/// minutes, and the exchange only accepts the payin while the order is alive.
/// A session outliving that deadline turns a failed negotiation into funds sent
/// against a dead order — the counterparty broadcasts our original transaction,
/// or we do at our own expiry, hours after the order expired.
///
/// So the session is bounded by the order, never by the user's global payjoin
/// setting.
class PayjoinSessionWindow {
  /// The session lifetime in seconds for a payjoin whose payment must reach the
  /// exchange before [deadline], or null when payjoin must not be attempted at
  /// all and the caller should send a plain transaction instead.
  ///
  /// Returns null once less than [PayjoinConstants.minExpireAfterSec] remains:
  /// the payjoin directory holds a long poll for roughly 30 seconds, so a
  /// shorter session cannot survive even one full cycle. Attempting it would
  /// only add a round trip before the inevitable fallback, against an order
  /// about to expire.
  static int? forOrderDeadline(DateTime deadline, {DateTime? now}) {
    final remaining = deadline.difference(now ?? DateTime.now()).inSeconds;

    if (remaining < PayjoinConstants.minExpireAfterSec) return null;

    // The protocol ceiling still applies: an order deadline further out than
    // 24 hours (a schedule change, a clock skew) must not produce a session the
    // PDK would refuse to build.
    return remaining > PayjoinConstants.maxExpireAfterSec
        ? PayjoinConstants.maxExpireAfterSec
        : remaining;
  }
}

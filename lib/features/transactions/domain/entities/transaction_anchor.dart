import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';

/// Why a single anchor sits where it does. Drives the wording beside the
/// value, so the number never silently claims to be the send moment.
enum AnchorReason {
  /// The user sent it, and the app recorded the broadcast moment.
  sent,

  /// The transaction confirmed. For an incoming on-chain payment this can be
  /// well after the sender actually sent.
  confirmed,

  /// A swap settled, which follows the payment by seconds.
  settled,
}

/// The moment, or the window, a transaction's historical value is read at.
sealed class TransactionAnchor {
  const TransactionAnchor();

  /// A locktime at or above this is a unix timestamp, not a block height.
  static const locktimeIsTimestampFrom = 500000000;

  /// The longest mempool wait, in blocks, that still earns a range.
  ///
  /// The start of the range is estimated at ten minutes a block, because the
  /// app has no way to read a block header by height: BDK exposes only the
  /// chain tip. Three blocks holds the estimate error near half an hour. A
  /// longer wait falls back to a single confirmation price rather than
  /// stating a window the app cannot stand behind.
  static const maxRangeBlocks = 3;

  static const _blockInterval = Duration(minutes: 10);

  /// Resolves where to read [transaction]'s historical value.
  ///
  /// [sentAt] is the recorded broadcast moment, when one exists. It is local
  /// and does not survive a seed restore, so an outgoing transaction without
  /// it degrades to confirmation-time anchoring — the same behaviour an
  /// incoming one already has.
  static TransactionAnchor of(Transaction transaction, {DateTime? sentAt}) {
    // An exchange order carries the rate it actually got. Showing a market
    // index beside it would contradict the true figure.
    if (transaction.isOrder) return const NoAnchor();

    final wt = transaction.walletTransaction;

    // Nothing moved, so a value would read as income or spend.
    if (wt?.isToSelf ?? false) return const NoAnchor();

    // A swap settles within seconds of the payment, so it needs no bounding.
    final swap = transaction.swap;
    if (swap != null) {
      if (!transaction.isOutgoing) {
        final settled = swap.completionTime ?? swap.creationTime;
        return SingleAnchor(at: settled, reason: AnchorReason.settled);
      }
      if (sentAt != null) {
        return SingleAnchor(at: sentAt, reason: AnchorReason.sent);
      }
      final settled = swap.completionTime ?? swap.creationTime;
      return SingleAnchor(at: settled, reason: AnchorReason.settled);
    }

    if (wt == null) return const NoAnchor();

    // The user sent it and the app was there. This is the only exact case.
    if (wt.isOutgoing && sentAt != null) {
      return SingleAnchor(at: sentAt, reason: AnchorReason.sent);
    }

    final confirmedAt = wt.confirmationTime;
    if (confirmedAt == null) return const NoAnchor();

    final single = SingleAnchor(
      at: confirmedAt,
      reason: AnchorReason.confirmed,
    );

    // Only an incoming on-chain bitcoin payment has an unknowable send moment
    // worth bounding. Liquid confirms in about a minute.
    if (!wt.isIncoming || !wt.isBitcoin) return single;

    final lockTime = wt.lockTime;
    final height = wt.confirmationHeight;
    if (lockTime == null || height == null) return single;
    if (lockTime <= 0 || lockTime >= locktimeIsTimestampFrom) return single;

    final gap = height - lockTime;
    if (gap < 0 || gap > maxRangeBlocks) return single;

    return RangeAnchor(
      from: confirmedAt.subtract(_blockInterval * gap),
      to: confirmedAt,
    );
  }
}

/// Nothing to show. A real answer, not a failure.
class NoAnchor extends TransactionAnchor {
  const NoAnchor();
}

/// One moment, with the reason it was chosen.
class SingleAnchor extends TransactionAnchor {
  final DateTime at;
  final AnchorReason reason;
  const SingleAnchor({required this.at, required this.reason});
}

/// A window the payment was broadcast somewhere inside.
class RangeAnchor extends TransactionAnchor {
  final DateTime from;
  final DateTime to;
  const RangeAnchor({required this.from, required this.to});
}

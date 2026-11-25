import 'package:meta/meta.dart';

/// What sending a sell or pay payin did: the closed broadcast set at the
/// boundary between the wallet's spend and the exchange flows. Only
/// [PayinBroadcastRefused] and [PayinBroadcastNotSent] say that nothing is on
/// the network; after any other answer the payin may have gone out and is
/// never offered again.
@immutable
sealed class PayinBroadcastOutcome {
  const PayinBroadcastOutcome();
}

/// A node took the transaction.
final class PayinBroadcastAccepted extends PayinBroadcastOutcome {
  final String txid;

  const PayinBroadcastAccepted(this.txid);

  @override
  bool operator ==(Object other) =>
      other is PayinBroadcastAccepted && other.txid == txid;

  @override
  int get hashCode => Object.hash(PayinBroadcastAccepted, txid);

  @override
  String toString() => 'PayinBroadcastAccepted($txid)';
}

/// A payjoin session took the payin over: it broadcasts the proposal or the
/// original transaction [originalTxid] itself.
final class PayinHandedToPayjoin extends PayinBroadcastOutcome {
  final String sessionId;
  final String originalTxid;

  const PayinHandedToPayjoin(this.sessionId, this.originalTxid);

  @override
  bool operator ==(Object other) =>
      other is PayinHandedToPayjoin &&
      other.sessionId == sessionId &&
      other.originalTxid == originalTxid;

  @override
  int get hashCode =>
      Object.hash(PayinHandedToPayjoin, sessionId, originalTxid);

  @override
  String toString() => 'PayinHandedToPayjoin($sessionId, $originalTxid)';
}

enum PayinRefusal {
  /// The node refused the transaction: it is not on the network.
  nodeRejected,

  /// The payjoin session could not start, and nothing of it was kept.
  payjoinNotStarted,
}

/// Sent, and refused: nothing is on the network.
final class PayinBroadcastRefused extends PayinBroadcastOutcome {
  final PayinRefusal reason;

  const PayinBroadcastRefused(this.reason);

  @override
  bool operator ==(Object other) =>
      other is PayinBroadcastRefused && other.reason == reason;

  @override
  int get hashCode => Object.hash(PayinBroadcastRefused, reason);

  @override
  String toString() => 'PayinBroadcastRefused(${reason.name})';
}

enum PayinNotSentReason {
  /// The order's payment deadline passed before sending: the exchange would
  /// not credit it.
  deadlinePassed,

  /// The wallet is busy with another spend (the spend's blocked status).
  walletBusy,

  /// No server was reached.
  noConnection,

  /// This build may not spend on this network.
  notAuthorized,
}

/// The payin never left the app.
final class PayinBroadcastNotSent extends PayinBroadcastOutcome {
  final PayinNotSentReason reason;

  const PayinBroadcastNotSent(this.reason);

  @override
  bool operator ==(Object other) =>
      other is PayinBroadcastNotSent && other.reason == reason;

  @override
  int get hashCode => Object.hash(PayinBroadcastNotSent, reason);

  @override
  String toString() => 'PayinBroadcastNotSent(${reason.name})';
}

/// The payin may be on the network ([txid] when the app knows it). Never
/// build or send another one; look it up instead.
final class PayinBroadcastOutcomeUnknown extends PayinBroadcastOutcome {
  final String? txid;

  const PayinBroadcastOutcomeUnknown(this.txid);

  @override
  bool operator ==(Object other) =>
      other is PayinBroadcastOutcomeUnknown && other.txid == txid;

  @override
  int get hashCode => Object.hash(PayinBroadcastOutcomeUnknown, txid);

  @override
  String toString() => 'PayinBroadcastOutcomeUnknown($txid)';
}

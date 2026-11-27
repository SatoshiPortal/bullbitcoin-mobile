import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Outpoint;

import '../bitcoin/bitcoin_rail.dart';
import '../domain/entities/btc_network.dart';
import '../domain/entities/order.dart';
import '../domain/exchange_access.dart';
import '../domain/exchange_call_result.dart';
import '../domain/exchange_write_gate.dart';
import '../domain/payin_broadcast.dart';
import '../domain/unknown_write_journal.dart';
import 'outcome_watch.dart';
import 'payin_wallet_admission.dart';
import 'pick.dart';
import 'server_confirm.dart';
import 'step_next.dart';

bool _sameProps(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Value equality over [props] and the exact runtime type.
@immutable
abstract base class _PayinValue {
  const _PayinValue();

  List<Object?> get props;

  @override
  bool operator ==(Object other) =>
      other is _PayinValue &&
      other.runtimeType == runtimeType &&
      _sameProps(other.props, props);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(props));

  @override
  String toString() => '$runtimeType(${props.join(', ')})';
}

/// The bounds of the order watch after the payin left (and of an external
/// payin's wait).
@immutable
final class PayinPolicy {
  final int maxPolls;
  final Duration maxDuration;
  final int maxUnreadable;

  const PayinPolicy({
    required this.maxPolls,
    required this.maxDuration,
    required this.maxUnreadable,
  });

  /// The watch of an order whose payin goes to [target]: done once the
  /// exchange saw the payin ([payinVerdict]).
  OutcomePolicy<Order> watchFor(DepositTarget target) => OutcomePolicy<Order>(
    idOf: _orderIdOf,
    verdictOf: (order) => payinVerdict(target, order),
    hasReceipt: _noReceipt,
    maxPolls: maxPolls,
    maxDuration: maxDuration,
    maxUnreadable: maxUnreadable,
  );
}

String _orderIdOf(Order order) => order.orderId;

bool _noReceipt(Order order) => false;

/// Whether the exchange saw the payin to [target]: done once it did (held
/// for review included); failed when it refused it, or the order ended or
/// moved its deposit without seeing it (SELL-1, SELL-4); otherwise pending.
/// An unknown payin status is pending, so it is watched within its bounds
/// and never taken for an outcome.
OutcomeVerdict payinVerdict(DepositTarget target, Order order) =>
    switch (order.payinStatus) {
      OrderPayinStatus.inProgress ||
      OrderPayinStatus.underReview ||
      OrderPayinStatus.awaitingConfirmation ||
      OrderPayinStatus.completed => OutcomeVerdict.done,
      OrderPayinStatus.rejected => OutcomeVerdict.failed,
      OrderPayinStatus.notStarted ||
      OrderPayinStatus.awaitingPayment ||
      OrderPayinStatus.unknown =>
        order.orderStatus.isTerminal ||
                !target.network.rail.keepsDeposit(target, order)
            ? OutcomeVerdict.failed
            : OutcomeVerdict.pending,
    };

/// Only a payin the exchange shows as not started or awaiting payment may
/// be sent. Any other status, an unknown one included, may mean a payin is
/// already on its way.
bool _awaitsPayin(Order order) => switch (order.payinStatus) {
  OrderPayinStatus.notStarted || OrderPayinStatus.awaitingPayment => true,
  OrderPayinStatus.inProgress ||
  OrderPayinStatus.underReview ||
  OrderPayinStatus.awaitingConfirmation ||
  OrderPayinStatus.completed ||
  OrderPayinStatus.rejected ||
  OrderPayinStatus.unknown => false,
};

bool _pastDeadline(Order order, DateTime at) {
  final deadline = order.confirmationDeadline;
  return deadline != null && !at.isBefore(deadline);
}

/// The payin sources a sell or pay offers: each app wallet whose rail can
/// pay from the app, and every rail that can be paid from outside.
List<PayinOption> payinOptionsFor(Map<String, BtcNetwork> appWallets) => [
  for (final MapEntry(key: walletId, value: network) in appWallets.entries)
    if (network.rail.canBeAppWallet) PayinOptionAppWallet(walletId, network),
  for (final rail in BitcoinRails.all)
    if (rail.canBeExternalPayin) PayinOptionExternal(rail.network),
];

/// The open journal entry of a payin to [orderId], if any. A payin with one
/// starts in Verifying, never offering the send again.
UnknownWrite? openPayinEntryFor(String orderId, List<UnknownWrite> entries) {
  for (final entry in entries) {
    if (entry.kind == UnknownWriteKind.payin && entry.orderId == orderId) {
      return entry;
    }
  }
  return null;
}

/// The fee a payin is built at, chosen on the review before Building.
@immutable
sealed class PayinFee extends _PayinValue {
  const PayinFee();
}

/// A fee rate in sat per kilo-weight-unit (250 sat/kwu = 1 sat/vB).
final class PayinFeeRate extends PayinFee {
  final int satPerKwu;

  const PayinFeeRate(this.satPerKwu);

  @override
  List<Object?> get props => [satPerKwu];
}

/// An absolute fee in sats.
final class PayinFeeAbsolute extends PayinFee {
  final int sats;

  const PayinFeeAbsolute(this.sats);

  @override
  List<Object?> get props => [sats];
}

/// The network's minimum relay fee (Liquid: nothing to choose).
final class PayinFeeNetworkMinimum extends PayinFee {
  const PayinFeeNetworkMinimum();

  @override
  List<Object?> get props => const [];
}

/// How an app-wallet payin is built: the fee, replace-by-fee, the coins
/// picked by hand (empty: the wallet picks) and whether a payjoin the order
/// offers is used. Chosen before Building and carried with it, so a rebuild
/// after a refused broadcast uses the same choice; a resend of the same
/// signed transaction never reads it.
final class PayinSpendOptions extends _PayinValue {
  final PayinFee fee;
  final bool replaceByFee;
  final Set<Outpoint> coins;
  final bool payjoin;

  const PayinSpendOptions({
    required this.fee,
    required this.replaceByFee,
    required this.coins,
    required this.payjoin,
  });

  /// A Liquid payin: the network minimum, no other choice.
  static const liquid = PayinSpendOptions(
    fee: PayinFeeNetworkMinimum(),
    replaceByFee: false,
    coins: {},
    payjoin: false,
  );

  @override
  List<Object?> get props => [
    fee,
    replaceByFee,
    ([...coins]..sort(_byOutpoint)).join(','),
    payjoin,
  ];
}

int _byOutpoint(Outpoint a, Outpoint b) {
  final byTx = a.txId.compareTo(b.txId);
  return byTx != 0 ? byTx : a.vout.compareTo(b.vout);
}

/// The app wallet a payin is built from and how.
final class PayinWalletSpend extends _PayinValue {
  final String walletId;
  final PayinSpendOptions options;
  final PayinWalletAttempt? walletAttempt;

  const PayinWalletSpend(this.walletId, this.options, {this.walletAttempt});

  @override
  List<Object?> get props => [walletId, options, walletAttempt];
}

/// A signed payin ready to send: [payload] is the wallet's own signed spend
/// (opaque here), [txid] read from the signed transaction (SELL-12).
final class PayinBuilt<P> extends _PayinValue {
  final PayinWalletSpend spend;
  final String txid;
  final P payload;

  const PayinBuilt(this.spend, this.txid, this.payload);

  String get walletId => spend.walletId;

  @override
  List<Object?> get props => [spend, txid, payload];
}

enum PayinBuildProblem {
  insufficientFunds,
  feeTooLow,
  walletBusy,
  consolidationRequired,
  signingRefused,
  notAuthorized,
  invalid,
  unexpected,
}

/// What building (preparing and signing) the payin gave. Nothing is sent
/// while building.
@immutable
sealed class PayinBuildResult<P> {
  const PayinBuildResult();
}

final class PayinBuildOk<P> extends PayinBuildResult<P> {
  final PayinBuilt<P> built;

  const PayinBuildOk(this.built);
}

final class PayinBuildFailed<P> extends PayinBuildResult<P> {
  final PayinBuildProblem problem;

  const PayinBuildFailed(this.problem);
}

/// Why nothing went out.
@immutable
sealed class PayinProblem extends _PayinValue {
  const PayinProblem();
}

final class PayinBuildRefused extends PayinProblem {
  final PayinBuildProblem reason;

  const PayinBuildRefused(this.reason);

  @override
  List<Object?> get props => [reason];
}

final class PayinSendRefused extends PayinProblem {
  final PayinRefusal reason;

  const PayinSendRefused(this.reason);

  @override
  List<Object?> get props => [reason];
}

final class PayinSendNotSent extends PayinProblem {
  final PayinNotSentReason reason;

  const PayinSendNotSent(this.reason);

  @override
  List<Object?> get props => [reason];
}

/// What a retry does once the re-read shows the order still takes the
/// payin: build a new one (nothing of the last one can be on the network) or
/// send the same signed transaction again (the same txid can't pay twice).
@immutable
sealed class PayinResume<P> extends _PayinValue {
  const PayinResume();
}

final class PayinResumeBuild<P> extends PayinResume<P> {
  final PayinWalletSpend spend;

  const PayinResumeBuild(this.spend);

  @override
  List<Object?> get props => [spend];
}

final class PayinResumeSend<P> extends PayinResume<P> {
  final PayinBuilt<P> built;

  const PayinResumeSend(this.built);

  @override
  List<Object?> get props => [built];
}

/// What a payjoin session reports.
@immutable
sealed class PayjoinProgress {
  const PayjoinProgress();
}

final class PayjoinNegotiating extends PayjoinProgress {
  const PayjoinNegotiating();
}

/// The session can't spend its inputs right now; the user may retry it.
final class PayjoinPaused extends PayjoinProgress {
  const PayjoinPaused();
}

/// The session broadcast the proposal or the original transaction [txid].
final class PayjoinSent extends PayjoinProgress {
  final String txid;

  const PayjoinSent(this.txid);
}

/// The session ended without a broadcast of its own. The receiver may still
/// have broadcast the original, so the payin is looked up, never re-armed
/// (SELL-3).
final class PayjoinExpired extends PayjoinProgress {
  const PayjoinExpired();
}

/// What the look-up of a payin whose outcome is unknown shows.
@immutable
sealed class PayinCheck {
  const PayinCheck();
}

final class PayinCheckSeenOnNetwork extends PayinCheck {
  final String txid;

  const PayinCheckSeenOnNetwork(this.txid);
}

final class PayinCheckSeenByExchange extends PayinCheck {
  final Order order;

  const PayinCheckSeenByExchange(this.order);
}

/// Neither the network nor the exchange shows it yet. That is no proof it
/// did not go out.
final class PayinCheckNotSeen extends PayinCheck {
  const PayinCheckNotSeen();
}

final class PayinCheckFailed extends PayinCheck {
  final ReadProblem problem;

  const PayinCheckFailed(this.problem);
}

final class PayinCheckSessionRejected extends PayinCheck {
  const PayinCheckSessionRejected();
}

/// The answer of a [PayinVerify] look-up: [txSeen] is whether the source
/// wallet or its network shows [txid] (null when that look-up failed), [order]
/// the re-read of the order. Proof wins over doubt: a seen transaction or a
/// payin the exchange shows settles it even when the other read failed; a
/// payin is "not seen" only when both reads worked and show nothing.
PayinCheck payinCheckFrom({
  required String? txid,
  required bool? txSeen,
  required ExchangeRead<Order> order,
}) {
  if (order is ReadSessionRejected<Order>) {
    return const PayinCheckSessionRejected();
  }
  if (order case ReadGot(value: final read) when !_awaitsPayin(read)) {
    return PayinCheckSeenByExchange(read);
  }
  if (txSeen == true && txid != null) return PayinCheckSeenOnNetwork(txid);
  final problem = ReadProblem.of(order);
  if (problem != null) return PayinCheckFailed(problem);
  if (txSeen == null && txid != null) {
    return const PayinCheckFailed(ReadProblemUnreachable(isNetwork: true));
  }
  return const PayinCheckNotSeen();
}

/// The payin of a sell or pay order (state-machines Phase 3, composition
/// §4.8 Payin), on the source's [BitcoinRail]. [P] is the wallet's signed
/// spend.
///
/// The send exists only in [PayinBuilding] → [PayinBroadcasting]. Once a send
/// may have gone out ([PayinBroadcastOutcomeUnknown], a payjoin session, an
/// unknown payin status) no state builds a new one: Verifying looks it up,
/// and at most the same signed transaction is sent again. Every retry
/// re-reads the order first ([PayinRechecking]).
@immutable
sealed class PayinState<P> extends _PayinValue {
  const PayinState();
}

/// Preparing and signing from the app wallet; nothing is sent.
final class PayinBuilding<P> extends PayinState<P> {
  final Order order;
  final DepositTarget target;
  final PayinWalletSpend spend;
  final int attempt;

  const PayinBuilding(this.order, this.target, this.spend, this.attempt);

  @override
  List<Object?> get props => [order, target, spend, attempt];
}

/// Sending through the account's write gate.
final class PayinBroadcasting<P> extends PayinState<P> {
  final Order order;
  final DepositTarget target;
  final int attempt;
  final PayinBuilt<P> built;

  const PayinBroadcasting(this.order, this.target, this.attempt, this.built);

  @override
  List<Object?> get props => [order, target, attempt, built];
}

/// The write gate refused the send; nothing was sent.
final class PayinWriteRefused<P> extends PayinState<P> {
  final Order order;
  final DepositTarget target;
  final int attempt;
  final PayinBuilt<P> built;
  final WriteGateRefusal refusal;

  const PayinWriteRefused(
    this.order,
    this.target,
    this.attempt,
    this.built,
    this.refusal,
  );

  @override
  List<Object?> get props => [order, target, attempt, built, refusal];
}

/// Nothing went out. Retry re-reads the order first.
final class PayinSendFailed<P> extends PayinState<P> {
  final Order order;
  final DepositTarget target;
  final int attempt;
  final PayinResume<P> resume;
  final PayinProblem problem;

  const PayinSendFailed(
    this.order,
    this.target,
    this.attempt,
    this.resume,
    this.problem,
  );

  @override
  List<Object?> get props => [order, target, attempt, resume, problem];
}

/// Re-reading the order before a retry.
final class PayinRechecking<P> extends PayinState<P> {
  final Order order;
  final DepositTarget target;
  final int attempt;
  final PayinResume<P> resume;

  const PayinRechecking(this.order, this.target, this.attempt, this.resume);

  @override
  List<Object?> get props => [order, target, attempt, resume];
}

/// The re-read before a retry failed.
final class PayinRecheckFailed<P> extends PayinState<P> {
  final Order order;
  final DepositTarget target;
  final int attempt;
  final PayinResume<P> resume;
  final ReadProblem problem;

  const PayinRecheckFailed(
    this.order,
    this.target,
    this.attempt,
    this.resume,
    this.problem,
  );

  @override
  List<Object?> get props => [order, target, attempt, resume, problem];
}

/// A payjoin session owns the payin and will broadcast the proposal or the
/// original [originalTxid]. Back is a stay.
final class PayinPayjoinNegotiating<P> extends PayinState<P> {
  final Order order;
  final DepositTarget target;
  final int attempt;
  final String sessionId;
  final String originalTxid;

  const PayinPayjoinNegotiating(
    this.order,
    this.target,
    this.attempt,
    this.sessionId,
    this.originalTxid,
  );

  @override
  List<Object?> get props => [order, target, attempt, sessionId, originalTxid];
}

/// The session can't spend its inputs right now; Retry asks it again.
final class PayinPayjoinPaused<P> extends PayinState<P> {
  final Order order;
  final DepositTarget target;
  final int attempt;
  final String sessionId;
  final String originalTxid;

  const PayinPayjoinPaused(
    this.order,
    this.target,
    this.attempt,
    this.sessionId,
    this.originalTxid,
  );

  @override
  List<Object?> get props => [order, target, attempt, sessionId, originalTxid];
}

/// The payin may be on the network: looking [txid] up and re-reading the
/// order. Back is a stay. [built] is kept so the same transaction can be
/// sent again; it is null when the app holds none (a payjoin session, a
/// journal entry from before).
final class PayinVerifying<P> extends PayinState<P> {
  final Order order;
  final DepositTarget target;
  final int attempt;
  final String? txid;
  final PayinBuilt<P>? built;

  const PayinVerifying(
    this.order,
    this.target,
    this.attempt,
    this.txid,
    this.built,
  );

  @override
  List<Object?> get props => [order, target, attempt, txid, built];
}

/// The look-up did not find the payin. It may still be out, so no new payin
/// is built: look again, send the same signed transaction again (when the
/// app holds it), or leave with the journal entry open.
final class PayinUnseen<P> extends PayinState<P> {
  final Order order;
  final DepositTarget target;
  final int attempt;
  final String? txid;
  final PayinBuilt<P>? built;

  const PayinUnseen(
    this.order,
    this.target,
    this.attempt,
    this.txid,
    this.built,
  );

  @override
  List<Object?> get props => [order, target, attempt, txid, built];
}

/// The look-up failed. Retry looks again; leaving keeps the journal entry.
final class PayinUnverified<P> extends PayinState<P> {
  final Order order;
  final DepositTarget target;
  final int attempt;
  final String? txid;
  final PayinBuilt<P>? built;
  final ReadProblem problem;

  const PayinUnverified(
    this.order,
    this.target,
    this.attempt,
    this.txid,
    this.built,
    this.problem,
  );

  @override
  List<Object?> get props => [order, target, attempt, txid, built, problem];
}

/// The payin went out ([txid] when known): watching the order until the
/// exchange sees it. [watch] is the bounded, pausable order watch; its
/// Unreadable and TimedOut states show the reference with Leave and Retry.
final class PayinWatching<P> extends PayinState<P> {
  final Order order;
  final DepositTarget target;
  final String? txid;
  final OutcomeWatchState<Order> watch;

  const PayinWatching(this.order, this.target, this.txid, this.watch);

  @override
  List<Object?> get props => [order, target, txid, watch];
}

/// Paid from outside the app: the deposit is shown and the order watched.
/// Back asks first (PAY-4).
final class PayinExternal<P> extends PayinState<P> {
  final Order order;
  final DepositTarget target;
  final OutcomeWatchState<Order> watch;

  const PayinExternal(this.order, this.target, this.watch);

  @override
  List<Object?> get props => [order, target, watch];
}

/// Asking whether to leave an external payin; the watch keeps running.
final class PayinExternalLeaving<P> extends PayinState<P> {
  final Order order;
  final DepositTarget target;
  final OutcomeWatchState<Order> watch;

  const PayinExternalLeaving(this.order, this.target, this.watch);

  @override
  List<Object?> get props => [order, target, watch];
}

/// Output: the exchange saw the payin. Says "payment received by the
/// exchange", not "order completed" (SELL-11).
final class PayinCompleted<P> extends PayinState<P> {
  final Order order;
  final String? txid;

  const PayinCompleted(this.order, this.txid);

  CommittedOrder<Order> get committed => PayinSeen(order, txid);

  @override
  List<Object?> get props => [order, txid];
}

/// The exchange refused the payin, or the order ended or moved its deposit
/// without it, after it went out (or while it was awaited from outside).
/// Shows the reference and Leave. Terminal.
final class PayinRefusedByExchange<P> extends PayinState<P> {
  final Order order;
  final String? txid;

  const PayinRefusedByExchange(this.order, this.txid);

  @override
  List<Object?> get props => [order, txid];
}

/// The order's payment deadline passed before anything was sent; the flow
/// refreshes the quote. Terminal.
final class PayinQuoteLapsed<P> extends PayinState<P> {
  final Order order;

  const PayinQuoteLapsed(this.order);

  @override
  List<Object?> get props => [order];
}

/// The order ended before anything was sent. Terminal.
final class PayinOrderEnded<P> extends PayinState<P> {
  final Order order;

  const PayinOrderEnded(this.order);

  @override
  List<Object?> get props => [order];
}

/// The order has no deposit on the source's rail, or moved it, before
/// anything was sent: never paid (SELL-4). Terminal.
final class PayinDepositRefused<P> extends PayinState<P> {
  final Order order;

  const PayinDepositRefused(this.order);

  @override
  List<Object?> get props => [order];
}

/// Left with nothing sent. Terminal.
final class PayinLeft<P> extends PayinState<P> {
  const PayinLeft();

  @override
  List<Object?> get props => const [];
}

/// Left while a payin may be or is out; its journal entry (if any) stays
/// open for reconcile. Terminal.
final class PayinLeftPending<P> extends PayinState<P> {
  final Order order;
  final String? txid;

  const PayinLeftPending(this.order, this.txid);

  @override
  List<Object?> get props => [order, txid];
}

/// A call got HTTP 401: the flow ends its session. Terminal.
final class PayinSessionEnded<P> extends PayinState<P> {
  const PayinSessionEnded();

  @override
  List<Object?> get props => const [];
}

@immutable
sealed class PayinEvent<P> {
  const PayinEvent();
}

/// What building [attempt] gave, read at [at].
final class PayinBuildAnswered<P> extends PayinEvent<P> {
  final int attempt;
  final PayinBuildResult<P> result;
  final DateTime at;

  const PayinBuildAnswered(this.attempt, this.result, this.at);
}

/// What the write gate and the send of [attempt] answered.
final class PayinSendAnswered<P> extends PayinEvent<P> {
  final int attempt;
  final GatedWrite<PayinBroadcastOutcome> answer;

  const PayinSendAnswered(this.attempt, this.answer);
}

/// The re-read of the order for retry [attempt], read at [at].
final class PayinRechecked<P> extends PayinEvent<P> {
  final int attempt;
  final ExchangeRead<Order> read;
  final DateTime at;

  const PayinRechecked(this.attempt, this.read, this.at);
}

final class PayinVerified<P> extends PayinEvent<P> {
  final int attempt;
  final PayinCheck check;

  const PayinVerified(this.attempt, this.check);
}

final class PayinPayjoinUpdated<P> extends PayinEvent<P> {
  final String sessionId;
  final PayjoinProgress progress;

  const PayinPayjoinUpdated(this.sessionId, this.progress);
}

/// The session's update stream ended (PAY-6).
final class PayinPayjoinWatchEnded<P> extends PayinEvent<P> {
  final String sessionId;

  const PayinPayjoinWatchEnded(this.sessionId);
}

/// An event of the order watch (polls, visibility, deadline, retry, leave).
final class PayinWatchEvent<P> extends PayinEvent<P> {
  final OutcomeWatchEvent<Order> event;

  const PayinWatchEvent(this.event);
}

final class PayinRetryPressed<P> extends PayinEvent<P> {
  const PayinRetryPressed();
}

/// Send the same signed transaction again (after the order is re-read).
final class PayinResendPressed<P> extends PayinEvent<P> {
  const PayinResendPressed();
}

final class PayinBackPressed<P> extends PayinEvent<P> {
  const PayinBackPressed();
}

final class PayinLeaveConfirmed<P> extends PayinEvent<P> {
  const PayinLeaveConfirmed();
}

final class PayinLeaveCancelled<P> extends PayinEvent<P> {
  const PayinLeaveCancelled();
}

@immutable
sealed class PayinEffect<P> extends _PayinValue {
  const PayinEffect();
}

/// Prepare and sign the payin of [order] to [target] as [spend] says;
/// answer [PayinBuildAnswered] for [attempt]. Never broadcasts.
final class PayinBuild<P> extends PayinEffect<P> {
  final Order order;
  final DepositTarget target;
  final PayinWalletSpend spend;
  final int attempt;

  const PayinBuild(this.order, this.target, this.spend, this.attempt);

  String get walletId => spend.walletId;

  @override
  List<Object?> get props => [order, target, spend, attempt];
}

/// Send [built] through the write gate ([runPayinSend]); answer
/// [PayinSendAnswered] for [attempt].
final class PayinSend<P> extends PayinEffect<P> {
  final Order order;
  final DepositTarget target;
  final int attempt;
  final PayinBuilt<P> built;

  const PayinSend(this.order, this.target, this.attempt, this.built);

  @override
  List<Object?> get props => [order, target, attempt, built];
}

/// Re-read [orderId]; answer [PayinRechecked] for [attempt].
final class PayinRecheck<P> extends PayinEffect<P> {
  final String orderId;
  final int attempt;

  const PayinRecheck(this.orderId, this.attempt);

  @override
  List<Object?> get props => [orderId, attempt];
}

/// Look [txid] up on the source's network and re-read [order]; answer
/// [PayinVerified] for [attempt].
final class PayinVerify<P> extends PayinEffect<P> {
  final Order order;
  final DepositTarget target;
  final int attempt;
  final String? txid;

  const PayinVerify(this.order, this.target, this.attempt, this.txid);

  @override
  List<Object?> get props => [order, target, attempt, txid];
}

/// Follow the payjoin session; answer [PayinPayjoinUpdated] /
/// [PayinPayjoinWatchEnded].
final class PayinFollowPayjoin<P> extends PayinEffect<P> {
  final String sessionId;

  const PayinFollowPayjoin(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

final class PayinStopPayjoin<P> extends PayinEffect<P> {
  final String sessionId;

  const PayinStopPayjoin(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

/// Ask the paused session to try its proposal again.
final class PayinRetryPayjoin<P> extends PayinEffect<P> {
  final String sessionId;

  const PayinRetryPayjoin(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

/// An effect of the order watch.
final class PayinWatchEffect<P> extends PayinEffect<P> {
  final OutcomeWatchEffect effect;

  const PayinWatchEffect(this.effect);

  @override
  List<Object?> get props => [effect];
}

typedef PayinNext<P> = StepNext<PayinState<P>, PayinEffect<P>>;

/// The first state of the payin of [order] from [source], at [now]:
/// - no deposit on the source's rail → [PayinDepositRefused];
/// - an open payin journal entry for the order ([openPayinEntryFor]) →
///   [PayinVerifying] with the journaled txid, never a new send;
/// - a payin status other than not started / awaiting payment → watching;
/// - an ended order → [PayinOrderEnded]; past its deadline →
///   [PayinQuoteLapsed];
/// - otherwise build from the app wallet, or show the deposit for an
///   external payin.
PayinNext<P> payinStart<P>(
  PayinPolicy policy, {
  required Order order,
  required PayinSource source,
  required DateTime now,
  required PayinSpendOptions? options,
  UnknownWrite? openEntry,
}) {
  final rail = source.rail.rail;
  final target = switch (rail.depositOf(order)) {
    DepositGiven(target: final given) => given,
    DepositNotGiven() || DepositOnOtherRail() => null,
  };
  if (target == null) return StepNext(PayinDepositRefused<P>(order));
  if (openEntry != null) {
    return _verifying(order, target, 1, openEntry.request['txid'], null);
  }
  if (!_awaitsPayin(order)) {
    return _watching(policy, order, target, null);
  }
  if (order.orderStatus.isTerminal) return StepNext(PayinOrderEnded<P>(order));
  if (_pastDeadline(order, now)) return StepNext(PayinQuoteLapsed<P>(order));
  return switch (source) {
    PayinFromAppWallet(:final witness, :final attempt)
        when witness != null && attempt?.isCurrent != true =>
      StepNext(PayinDepositRefused<P>(order)),
    PayinFromAppWallet(:final walletId, :final attempt)
        when rail.canBeAppWallet =>
      switch (options) {
        final options? => _building(
          order,
          target,
          PayinWalletSpend(walletId, options, walletAttempt: attempt),
          1,
        ),
        null => throw ArgumentError.notNull('options'),
      },
    PayinFromAppWallet() => StepNext(PayinDepositRefused<P>(order)),
    PayinFromExternal() => _external(policy, order, target),
  };
}

/// Runs [PayinSend] through [gate] for [session]'s account as the payin
/// financial write. Right before sending it checks the order's deadline
/// (late timers can't send a payin the exchange won't credit). A send whose
/// outcome is unknown, or that throws (an unclassifiable error counts as
/// unknown), and a payin handed to a payjoin session are journaled by
/// [journalUnknown] before the answer is returned.
Future<PayinSendAnswered<P>> runPayinSend<P>({
  required ExchangeWriteGate gate,
  required ExchangeSession session,
  required PayinSend<P> effect,
  required DateTime Function() now,
  required Future<PayinBroadcastOutcome> Function(PayinBuilt<P> built) send,
  required Future<void> Function(
    String orderId,
    BtcNetwork network,
    String? txid,
  )
  journalUnknown,
}) async => PayinSendAnswered(
  effect.attempt,
  await gate.run(session, FinancialWriteKind.payin, () async {
    if (effect.built.spend.walletAttempt case final attempt?
        when !attempt.isCurrent) {
      return const PayinBroadcastNotSent(PayinNotSentReason.walletBusy);
    }
    if (_pastDeadline(effect.order, now())) {
      return const PayinBroadcastNotSent(PayinNotSentReason.deadlinePassed);
    }
    PayinBroadcastOutcome outcome;
    try {
      outcome = await send(effect.built);
    } on Object {
      outcome = PayinBroadcastOutcomeUnknown(effect.built.txid);
    }
    switch (outcome) {
      case PayinBroadcastOutcomeUnknown(:final txid):
        await journalUnknown(
          effect.order.orderId,
          effect.target.network,
          txid ?? effect.built.txid,
        );
      // From the handoff on the payjoin session broadcasts (the proposal or
      // the original), not the app: like an unknown broadcast, the payin is
      // journaled and reconcile settles it by re-reading the order.
      case PayinHandedToPayjoin(:final originalTxid):
        await journalUnknown(
          effect.order.orderId,
          effect.target.network,
          originalTxid,
        );
      case PayinBroadcastAccepted() ||
          PayinBroadcastRefused() ||
          PayinBroadcastNotSent():
        break;
    }
    return outcome;
  }),
);

PayinNext<P> _building<P>(
  Order order,
  DepositTarget target,
  PayinWalletSpend spend,
  int attempt,
) => StepNext(PayinBuilding<P>(order, target, spend, attempt), [
  PayinBuild<P>(order, target, spend, attempt),
]);

PayinNext<P> _broadcasting<P>(
  Order order,
  DepositTarget target,
  int attempt,
  PayinBuilt<P> built,
) => StepNext(PayinBroadcasting<P>(order, target, attempt, built), [
  PayinSend<P>(order, target, attempt, built),
]);

PayinNext<P> _rechecking<P>(
  Order order,
  DepositTarget target,
  int attempt,
  PayinResume<P> resume,
) => StepNext(PayinRechecking<P>(order, target, attempt, resume), [
  PayinRecheck<P>(order.orderId, attempt),
]);

PayinNext<P> _verifying<P>(
  Order order,
  DepositTarget target,
  int attempt,
  String? txid,
  PayinBuilt<P>? built, [
  List<PayinEffect<P>> before = const [],
]) => StepNext(PayinVerifying<P>(order, target, attempt, txid, built), [
  ...before,
  PayinVerify<P>(order, target, attempt, txid),
]);

PayinNext<P> _payjoin<P>(
  Order order,
  DepositTarget target,
  int attempt,
  String sessionId,
  String originalTxid,
) => StepNext(
  PayinPayjoinNegotiating<P>(order, target, attempt, sessionId, originalTxid),
  [PayinFollowPayjoin<P>(sessionId)],
);

Order _latest(Order order, OutcomeWatchState<Order> watch) => switch (watch) {
  WatchWatching(order: final o) ||
  WatchPaused(order: final o) ||
  WatchDone(order: final o) ||
  WatchReceipt(order: final o) ||
  WatchFailed(order: final o) ||
  WatchUnreadable(order: final o) ||
  WatchTimedOut(order: final o) => o,
  WatchSessionEnded() || WatchLeft() => order,
};

/// The payin state after the order watch moved to [next]: its outcomes end
/// the payin, its other states stay inside [keep].
PayinNext<P> _afterWatch<P>(
  Order order,
  String? txid,
  OutcomeWatchNext<Order> next,
  PayinState<P> Function(Order order, OutcomeWatchState<Order> watch) keep, [
  List<PayinEffect<P>> before = const [],
]) {
  final effects = [
    ...before,
    for (final effect in next.effects) PayinWatchEffect<P>(effect),
  ];
  final latest = _latest(order, next.state);
  return switch (next.state) {
    WatchDone() ||
    WatchReceipt() => StepNext(PayinCompleted<P>(latest, txid), effects),
    WatchFailed() => StepNext(PayinRefusedByExchange<P>(latest, txid), effects),
    WatchSessionEnded() => StepNext(PayinSessionEnded<P>(), effects),
    WatchLeft() => StepNext(PayinLeftPending<P>(latest, txid), effects),
    WatchWatching() ||
    WatchPaused() ||
    WatchUnreadable() ||
    WatchTimedOut() => StepNext(keep(latest, next.state), effects),
  };
}

PayinNext<P> _watching<P>(
  PayinPolicy policy,
  Order order,
  DepositTarget target,
  String? txid, [
  List<PayinEffect<P>> before = const [],
]) => _afterWatch(
  order,
  txid,
  outcomeWatchStart(policy.watchFor(target), order),
  (latest, watch) => PayinWatching<P>(latest, target, txid, watch),
  before,
);

PayinNext<P> _external<P>(
  PayinPolicy policy,
  Order order,
  DepositTarget target,
) => _afterWatch(
  order,
  null,
  outcomeWatchStart(policy.watchFor(target), order),
  (latest, watch) => PayinExternal<P>(latest, target, watch),
);

/// The order watch's answer to [event] inside a payin state, or null for a
/// stay.
PayinNext<P>? _watchStep<P>(
  PayinPolicy policy,
  Order order,
  DepositTarget target,
  String? txid,
  OutcomeWatchState<Order> watch,
  OutcomeWatchEvent<Order> event,
  PayinState<P> Function(Order order, OutcomeWatchState<Order> watch) keep,
) {
  final next = transitionOutcomeWatch(policy.watchFor(target), watch, event);
  if (identical(next.state, watch) && next.effects.isEmpty) return null;
  return _afterWatch(order, txid, next, keep);
}

PayinNext<P> _built<P>(
  Order order,
  DepositTarget target,
  PayinWalletSpend spend,
  int attempt,
  PayinBuildResult<P> result,
  DateTime at,
) => switch (result) {
  PayinBuildOk(:final built) =>
    _pastDeadline(order, at)
        ? StepNext(PayinQuoteLapsed<P>(order))
        : _broadcasting(order, target, attempt, built),
  PayinBuildFailed(:final problem) => StepNext(
    PayinSendFailed<P>(
      order,
      target,
      attempt,
      PayinResumeBuild<P>(spend),
      PayinBuildRefused(problem),
    ),
  ),
};

PayinNext<P> _sent<P>(
  PayinPolicy policy,
  Order order,
  DepositTarget target,
  int attempt,
  PayinBuilt<P> built,
  GatedWrite<PayinBroadcastOutcome> answer,
) => switch (answer) {
  GateRefused(refusal: WriteGateUnsettled(:final entry))
      when entry.kind == UnknownWriteKind.payin &&
          entry.orderId == order.orderId =>
    _verifying(order, target, attempt, built.txid, built),
  GateRefused(:final refusal) => StepNext(
    PayinWriteRefused<P>(order, target, attempt, built, refusal),
  ),
  GateAdmitted(result: PayinBroadcastAccepted(:final txid)) => _watching(
    policy,
    order,
    target,
    txid,
  ),
  GateAdmitted(
    result: PayinHandedToPayjoin(:final sessionId, :final originalTxid),
  ) =>
    _payjoin(order, target, attempt, sessionId, originalTxid),
  GateAdmitted(result: PayinBroadcastRefused(:final reason)) => StepNext(
    PayinSendFailed<P>(
      order,
      target,
      attempt,
      PayinResumeBuild<P>(built.spend),
      PayinSendRefused(reason),
    ),
  ),
  GateAdmitted(
    result: PayinBroadcastNotSent(reason: PayinNotSentReason.deadlinePassed),
  ) =>
    StepNext(PayinQuoteLapsed<P>(order)),
  GateAdmitted(result: PayinBroadcastNotSent(:final reason)) => StepNext(
    PayinSendFailed<P>(
      order,
      target,
      attempt,
      PayinResumeSend<P>(built),
      PayinSendNotSent(reason),
    ),
  ),
  GateAdmitted(result: PayinBroadcastOutcomeUnknown(:final txid)) => _verifying(
    order,
    target,
    attempt,
    txid ?? built.txid,
    built,
  ),
};

PayinNext<P> _rechecked<P>(
  PayinPolicy policy,
  PayinRechecking<P> state,
  ExchangeRead<Order> read,
  DateTime at,
) {
  final PayinRechecking(:target, :attempt, :resume) = state;
  switch (read) {
    case ReadGot(value: final order):
      if (!_awaitsPayin(order)) return _watching(policy, order, target, null);
      if (order.orderStatus.isTerminal) {
        return StepNext(PayinOrderEnded<P>(order));
      }
      if (!target.network.rail.keepsDeposit(target, order)) {
        return StepNext(PayinDepositRefused<P>(order));
      }
      if (_pastDeadline(order, at)) return StepNext(PayinQuoteLapsed<P>(order));
      return switch (resume) {
        PayinResumeBuild(:final spend) => _building(
          order,
          target,
          spend,
          attempt,
        ),
        PayinResumeSend(:final built) => _broadcasting(
          order,
          target,
          attempt,
          built,
        ),
      };
    case ReadSessionRejected():
      return StepNext(PayinSessionEnded<P>());
    case ReadMissing() || ReadUnreachable() || ReadMalformed():
      return StepNext(
        PayinRecheckFailed<P>(
          state.order,
          target,
          attempt,
          resume,
          ReadProblem.of(read)!,
        ),
      );
  }
}

PayinNext<P> _checked<P>(
  PayinPolicy policy,
  PayinVerifying<P> state,
  PayinCheck check,
) {
  final PayinVerifying(:order, :target, :attempt, :txid, :built) = state;
  return switch (check) {
    PayinCheckSeenOnNetwork(txid: final seen) => _watching(
      policy,
      order,
      target,
      seen,
    ),
    PayinCheckSeenByExchange(order: final seen) => _watching(
      policy,
      seen,
      target,
      txid,
    ),
    PayinCheckNotSeen() => StepNext(
      PayinUnseen<P>(order, target, attempt, txid, built),
    ),
    PayinCheckFailed(:final problem) => StepNext(
      PayinUnverified<P>(order, target, attempt, txid, built, problem),
    ),
    PayinCheckSessionRejected() => StepNext(PayinSessionEnded<P>()),
  };
}

PayinNext<P> _payjoinPaused<P>(PayinPayjoinNegotiating<P> s) => StepNext(
  PayinPayjoinPaused<P>(
    s.order,
    s.target,
    s.attempt,
    s.sessionId,
    s.originalTxid,
  ),
);

PayinNext<P> _payjoinResumed<P>(
  PayinPayjoinPaused<P> s, [
  List<PayinEffect<P>> effects = const [],
]) => StepNext(
  PayinPayjoinNegotiating<P>(
    s.order,
    s.target,
    s.attempt,
    s.sessionId,
    s.originalTxid,
  ),
  effects,
);

PayinNext<P> transitionPayin<P>(
  PayinPolicy policy,
  PayinState<P> state,
  PayinEvent<P> event,
) => switch ((state, event)) {
  (
    PayinBuilding(:final order, :final target, :final spend, :final attempt),
    PayinBuildAnswered(attempt: final answered, :final result, :final at),
  )
      when answered == attempt =>
    _built(order, target, spend, attempt, result, at),
  (PayinBuilding(), PayinBackPressed()) => StepNext(PayinLeft<P>()),
  (
    PayinBuilding(),
    PayinBuildAnswered() ||
        PayinSendAnswered() ||
        PayinRechecked() ||
        PayinVerified() ||
        PayinPayjoinUpdated() ||
        PayinPayjoinWatchEnded() ||
        PayinWatchEvent() ||
        PayinRetryPressed() ||
        PayinResendPressed() ||
        PayinLeaveConfirmed() ||
        PayinLeaveCancelled(),
  ) =>
    StepNext.stay(state),

  (
    PayinBroadcasting(
      :final order,
      :final target,
      :final attempt,
      :final built,
    ),
    PayinSendAnswered(attempt: final answered, :final answer),
  )
      when answered == attempt =>
    _sent(policy, order, target, attempt, built, answer),
  (
    PayinBroadcasting(),
    PayinBuildAnswered() ||
        PayinSendAnswered() ||
        PayinRechecked() ||
        PayinVerified() ||
        PayinPayjoinUpdated() ||
        PayinPayjoinWatchEnded() ||
        PayinWatchEvent() ||
        PayinRetryPressed() ||
        PayinResendPressed() ||
        PayinBackPressed() ||
        PayinLeaveConfirmed() ||
        PayinLeaveCancelled(),
  ) =>
    StepNext.stay(state),

  (
    PayinWriteRefused(
      :final order,
      :final target,
      :final attempt,
      :final built,
    ),
    PayinRetryPressed(),
  ) =>
    _rechecking(order, target, attempt + 1, PayinResumeSend<P>(built)),
  (PayinWriteRefused(), PayinBackPressed()) => StepNext(PayinLeft<P>()),
  (
    PayinSendFailed(:final order, :final target, :final attempt, :final resume),
    PayinRetryPressed(),
  ) =>
    _rechecking(order, target, attempt + 1, resume),
  (PayinSendFailed(), PayinBackPressed()) => StepNext(PayinLeft<P>()),
  (
    PayinWriteRefused() || PayinSendFailed(),
    PayinBuildAnswered() ||
        PayinSendAnswered() ||
        PayinRechecked() ||
        PayinVerified() ||
        PayinPayjoinUpdated() ||
        PayinPayjoinWatchEnded() ||
        PayinWatchEvent() ||
        PayinResendPressed() ||
        PayinLeaveConfirmed() ||
        PayinLeaveCancelled(),
  ) =>
    StepNext.stay(state),

  (
    final PayinRechecking<P> rechecking,
    PayinRechecked(attempt: final answered, :final read, :final at),
  )
      when answered == rechecking.attempt =>
    _rechecked(policy, rechecking, read, at),
  (
    PayinRechecking(),
    PayinBuildAnswered() ||
        PayinSendAnswered() ||
        PayinRechecked() ||
        PayinVerified() ||
        PayinPayjoinUpdated() ||
        PayinPayjoinWatchEnded() ||
        PayinWatchEvent() ||
        PayinRetryPressed() ||
        PayinResendPressed() ||
        PayinBackPressed() ||
        PayinLeaveConfirmed() ||
        PayinLeaveCancelled(),
  ) =>
    StepNext.stay(state),

  (
    PayinRecheckFailed(
      :final order,
      :final target,
      :final attempt,
      :final resume,
    ),
    PayinRetryPressed(),
  ) =>
    _rechecking(order, target, attempt, resume),
  (PayinRecheckFailed(), PayinBackPressed()) => StepNext(PayinLeft<P>()),
  (
    PayinRecheckFailed(),
    PayinBuildAnswered() ||
        PayinSendAnswered() ||
        PayinRechecked() ||
        PayinVerified() ||
        PayinPayjoinUpdated() ||
        PayinPayjoinWatchEnded() ||
        PayinWatchEvent() ||
        PayinResendPressed() ||
        PayinLeaveConfirmed() ||
        PayinLeaveCancelled(),
  ) =>
    StepNext.stay(state),

  (
    final PayinPayjoinNegotiating<P> negotiating,
    PayinPayjoinUpdated(:final sessionId, progress: PayjoinPaused()),
  )
      when sessionId == negotiating.sessionId =>
    _payjoinPaused(negotiating),
  (
    final PayinPayjoinPaused<P> paused,
    PayinPayjoinUpdated(:final sessionId, progress: PayjoinNegotiating()),
  )
      when sessionId == paused.sessionId =>
    _payjoinResumed(paused),
  (final PayinPayjoinPaused<P> paused, PayinRetryPressed()) => _payjoinResumed(
    paused,
    [PayinRetryPayjoin<P>(paused.sessionId)],
  ),
  (
    PayinPayjoinNegotiating(:final order, :final target, :final sessionId) ||
        PayinPayjoinPaused(:final order, :final target, :final sessionId),
    PayinPayjoinUpdated(
      sessionId: final updated,
      progress: PayjoinSent(:final txid),
    ),
  )
      when updated == sessionId =>
    _watching(policy, order, target, txid, [PayinStopPayjoin<P>(sessionId)]),
  (
    PayinPayjoinNegotiating(
          :final order,
          :final target,
          :final attempt,
          :final sessionId,
          :final originalTxid,
        ) ||
        PayinPayjoinPaused(
          :final order,
          :final target,
          :final attempt,
          :final sessionId,
          :final originalTxid,
        ),
    PayinPayjoinUpdated(sessionId: final updated, progress: PayjoinExpired()),
  )
      when updated == sessionId =>
    _verifying(order, target, attempt, originalTxid, null, [
      PayinStopPayjoin<P>(sessionId),
    ]),
  (
    PayinPayjoinNegotiating(
          :final order,
          :final target,
          :final attempt,
          :final sessionId,
          :final originalTxid,
        ) ||
        PayinPayjoinPaused(
          :final order,
          :final target,
          :final attempt,
          :final sessionId,
          :final originalTxid,
        ),
    PayinPayjoinWatchEnded(sessionId: final ended),
  )
      when ended == sessionId =>
    _verifying(order, target, attempt, originalTxid, null),
  (
    PayinPayjoinNegotiating() || PayinPayjoinPaused(),
    PayinBuildAnswered() ||
        PayinSendAnswered() ||
        PayinRechecked() ||
        PayinVerified() ||
        PayinPayjoinUpdated() ||
        PayinPayjoinWatchEnded() ||
        PayinWatchEvent() ||
        PayinRetryPressed() ||
        PayinResendPressed() ||
        PayinBackPressed() ||
        PayinLeaveConfirmed() ||
        PayinLeaveCancelled(),
  ) =>
    StepNext.stay(state),

  (
    final PayinVerifying<P> verifying,
    PayinVerified(attempt: final answered, :final check),
  )
      when answered == verifying.attempt =>
    _checked(policy, verifying, check),
  (
    PayinVerifying(),
    PayinBuildAnswered() ||
        PayinSendAnswered() ||
        PayinRechecked() ||
        PayinVerified() ||
        PayinPayjoinUpdated() ||
        PayinPayjoinWatchEnded() ||
        PayinWatchEvent() ||
        PayinRetryPressed() ||
        PayinResendPressed() ||
        PayinBackPressed() ||
        PayinLeaveConfirmed() ||
        PayinLeaveCancelled(),
  ) =>
    StepNext.stay(state),

  (
    PayinUnseen(
          :final order,
          :final target,
          :final attempt,
          :final txid,
          :final built,
        ) ||
        PayinUnverified(
          :final order,
          :final target,
          :final attempt,
          :final txid,
          :final built,
        ),
    PayinRetryPressed(),
  ) =>
    _verifying(order, target, attempt, txid, built),
  (
    PayinUnseen(:final order, :final target, :final attempt, :final built?),
    PayinResendPressed(),
  ) =>
    _rechecking(order, target, attempt + 1, PayinResumeSend<P>(built)),
  (
    PayinUnseen(:final order, :final txid) ||
        PayinUnverified(:final order, :final txid),
    PayinBackPressed(),
  ) =>
    StepNext(PayinLeftPending<P>(order, txid)),
  (
    PayinUnseen() || PayinUnverified(),
    PayinBuildAnswered() ||
        PayinSendAnswered() ||
        PayinRechecked() ||
        PayinVerified() ||
        PayinPayjoinUpdated() ||
        PayinPayjoinWatchEnded() ||
        PayinWatchEvent() ||
        PayinResendPressed() ||
        PayinLeaveConfirmed() ||
        PayinLeaveCancelled(),
  ) =>
    StepNext.stay(state),

  (
    PayinWatching(:final order, :final target, :final txid, :final watch),
    PayinWatchEvent(event: final watchEvent),
  ) =>
    _watchStep(
          policy,
          order,
          target,
          txid,
          watch,
          watchEvent,
          (latest, next) => PayinWatching<P>(latest, target, txid, next),
        ) ??
        StepNext.stay(state),
  (
    PayinWatching(:final order, :final target, :final txid, :final watch),
    PayinBackPressed(),
  ) =>
    _watchStep(
          policy,
          order,
          target,
          txid,
          watch,
          const WatchLeavePressed<Order>(),
          (latest, next) => PayinWatching<P>(latest, target, txid, next),
        ) ??
        StepNext.stay(state),
  (
    PayinWatching(),
    PayinBuildAnswered() ||
        PayinSendAnswered() ||
        PayinRechecked() ||
        PayinVerified() ||
        PayinPayjoinUpdated() ||
        PayinPayjoinWatchEnded() ||
        PayinRetryPressed() ||
        PayinResendPressed() ||
        PayinLeaveConfirmed() ||
        PayinLeaveCancelled(),
  ) =>
    StepNext.stay(state),

  (
    PayinExternal(:final order, :final target, :final watch),
    PayinWatchEvent(event: final watchEvent),
  ) =>
    _watchStep(
          policy,
          order,
          target,
          null,
          watch,
          watchEvent,
          (latest, next) => PayinExternal<P>(latest, target, next),
        ) ??
        StepNext.stay(state),
  (
    PayinExternal(:final order, :final target, :final watch),
    PayinBackPressed(),
  ) =>
    StepNext(PayinExternalLeaving<P>(order, target, watch)),
  (
    PayinExternal(),
    PayinBuildAnswered() ||
        PayinSendAnswered() ||
        PayinRechecked() ||
        PayinVerified() ||
        PayinPayjoinUpdated() ||
        PayinPayjoinWatchEnded() ||
        PayinRetryPressed() ||
        PayinResendPressed() ||
        PayinLeaveConfirmed() ||
        PayinLeaveCancelled(),
  ) =>
    StepNext.stay(state),

  (
    PayinExternalLeaving(:final order, :final target, :final watch),
    PayinWatchEvent(event: final watchEvent),
  ) =>
    _watchStep(
          policy,
          order,
          target,
          null,
          watch,
          watchEvent,
          (latest, next) => PayinExternalLeaving<P>(latest, target, next),
        ) ??
        StepNext.stay(state),
  (
    PayinExternalLeaving(:final order, :final target, :final watch),
    PayinLeaveConfirmed(),
  ) =>
    _watchStep(
          policy,
          order,
          target,
          null,
          watch,
          const WatchLeavePressed<Order>(),
          (latest, next) => PayinExternalLeaving<P>(latest, target, next),
        ) ??
        StepNext(PayinLeftPending<P>(order, null)),
  (
    PayinExternalLeaving(:final order, :final target, :final watch),
    PayinLeaveCancelled() || PayinBackPressed(),
  ) =>
    StepNext(PayinExternal<P>(order, target, watch)),
  (
    PayinExternalLeaving(),
    PayinBuildAnswered() ||
        PayinSendAnswered() ||
        PayinRechecked() ||
        PayinVerified() ||
        PayinPayjoinUpdated() ||
        PayinPayjoinWatchEnded() ||
        PayinRetryPressed() ||
        PayinResendPressed(),
  ) =>
    StepNext.stay(state),

  (
    PayinCompleted() ||
        PayinRefusedByExchange() ||
        PayinQuoteLapsed() ||
        PayinOrderEnded() ||
        PayinDepositRefused() ||
        PayinLeft() ||
        PayinLeftPending() ||
        PayinSessionEnded(),
    PayinBuildAnswered() ||
        PayinSendAnswered() ||
        PayinRechecked() ||
        PayinVerified() ||
        PayinPayjoinUpdated() ||
        PayinPayjoinWatchEnded() ||
        PayinWatchEvent() ||
        PayinRetryPressed() ||
        PayinResendPressed() ||
        PayinBackPressed() ||
        PayinLeaveConfirmed() ||
        PayinLeaveCancelled(),
  ) =>
    StepNext.stay(state),
};

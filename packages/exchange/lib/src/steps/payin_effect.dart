import 'package:meta/meta.dart';

import '../bitcoin/bitcoin_rail.dart';
import '../domain/entities/order.dart';
import 'outcome_watch_effect.dart';
import 'payin_event.dart';
import 'payin_state.dart';

@immutable
sealed class PayinEffect<P> extends PayinValue {
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

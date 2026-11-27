import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Result;

import '../domain/entities/order.dart';
import '../domain/exchange_failure.dart';
import '../domain/exchange_write_gate.dart';
import '../domain/payin_broadcast.dart';
import 'outcome_watch_event.dart';
import 'payin_state.dart';

@immutable
sealed class PayinEvent<P> {
  const PayinEvent();
}

/// What building (preparing and signing) [attempt] gave, read at [at].
/// Nothing is sent while building.
final class PayinBuildAnswered<P> extends PayinEvent<P> {
  final int attempt;
  final Result<PayinBuilt<P>, ExchangePayinBuildFailure> result;
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
  final Result<Order, ExchangeReadFailure> read;
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

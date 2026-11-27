import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Cancelling one limit order (LIM-3). Every state holds the order as last
/// read, so the page never shows a status the exchange did not report. Any
/// answer but a cancelled order re-reads it: the re-read, not the answer,
/// decides what the page shows and whether Cancel is offered again.
@immutable
sealed class LimitCancelState {
  const LimitCancelState();

  LimitOrder get order;

  /// The last cancel attempt; the next one is [attempt] + 1.
  int get attempt;

  /// The cancel step's transition.
  LimitCancelNext next(LimitCancelEvent event) {
    final state = this;
    return switch ((state, event)) {
      (CancelIdle(:final order, :final attempt), CancelPressed())
          when order.isActive =>
        StepNext(CancelSending(order, attempt + 1), [
          CancelSend(order.id, attempt + 1),
        ]),
      (
        CancelIdle(),
        CancelPressed() ||
            CancelAnswered() ||
            CancelChecked() ||
            CancelRetryPressed(),
      ) =>
        StepNext.stay(state),
      (
        CancelSending(:final order, :final attempt),
        CancelAnswered(attempt: final answered, :final answer),
      )
          when answered == attempt =>
        switch (answer) {
          CancelAnsweredOrder(order: final read) => _settled(read, attempt),
          CancelAnsweredGateRefused(:final refusal) => StepNext(
            CancelIdle(
              order,
              attempt: attempt,
              problem: CancelGateProblem(refusal),
            ),
          ),
          CancelAnsweredUnsure() => _checking(order, attempt),
          CancelAnsweredSessionRejected() => StepNext(
            CancelSessionEnded(order, attempt),
          ),
        },
      (
        CancelSending(),
        CancelPressed() ||
            CancelAnswered() ||
            CancelChecked() ||
            CancelRetryPressed(),
      ) =>
        StepNext.stay(state),
      (
        CancelChecking(:final order, :final attempt),
        CancelChecked(attempt: final answered, :final read),
      )
          when answered == attempt =>
        switch (read) {
          Ok(value: final reread) => _settled(reread, attempt),
          Err(failure: ExchangeSessionRejectedFailure()) => StepNext(
            CancelSessionEnded(order, attempt),
          ),
          Err(failure: ExchangeMissingFailure()) ||
          Err(failure: ExchangeUnreachableFailure()) ||
          Err(failure: ExchangeMalformedFailure()) => StepNext(
            CancelUnverified(order, attempt, ReadProblem.of(read)!),
          ),
        },
      (
        CancelChecking(),
        CancelPressed() ||
            CancelAnswered() ||
            CancelChecked() ||
            CancelRetryPressed(),
      ) =>
        StepNext.stay(state),
      (CancelUnverified(:final order, :final attempt), CancelRetryPressed()) =>
        _checking(order, attempt),
      (
        CancelUnverified(),
        CancelPressed() || CancelAnswered() || CancelChecked(),
      ) =>
        StepNext.stay(state),
      (
        CancelDone() || CancelSessionEnded(),
        CancelPressed() ||
            CancelAnswered() ||
            CancelChecked() ||
            CancelRetryPressed(),
      ) =>
        StepNext.stay(state),
    };
  }
}

/// Why the last cancel did not cancel the order.
@immutable
sealed class LimitCancelProblem {
  const LimitCancelProblem();
}

/// The account's write gate refused the cancel; nothing was sent.
final class CancelGateProblem extends LimitCancelProblem {
  final WriteGateRefusal refusal;

  const CancelGateProblem(this.refusal);

  @override
  bool operator ==(Object other) =>
      other is CancelGateProblem && other.refusal == refusal;

  @override
  int get hashCode => Object.hash(CancelGateProblem, refusal);
}

/// The order, read again, is not cancelled (still active, or it executed
/// or expired meanwhile).
final class CancelNotApplied extends LimitCancelProblem {
  const CancelNotApplied();

  @override
  bool operator ==(Object other) => other is CancelNotApplied;

  @override
  int get hashCode => (CancelNotApplied).hashCode;
}

/// The order as read; Cancel is offered when it is active.
final class CancelIdle extends LimitCancelState {
  @override
  final LimitOrder order;
  @override
  final int attempt;
  final LimitCancelProblem? problem;

  const CancelIdle(this.order, {this.attempt = 0, this.problem});

  @override
  bool operator ==(Object other) =>
      other is CancelIdle &&
      identical(other.order, order) &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(CancelIdle, order.id, attempt, problem);
}

final class CancelSending extends LimitCancelState {
  @override
  final LimitOrder order;
  @override
  final int attempt;

  const CancelSending(this.order, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is CancelSending &&
      identical(other.order, order) &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(CancelSending, order.id, attempt);
}

/// The cancel answered something other than a cancelled order: reading the
/// order again.
final class CancelChecking extends LimitCancelState {
  @override
  final LimitOrder order;
  @override
  final int attempt;

  const CancelChecking(this.order, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is CancelChecking &&
      identical(other.order, order) &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(CancelChecking, order.id, attempt);
}

/// The re-read failed; Retry reads again, it never cancels again.
final class CancelUnverified extends LimitCancelState {
  @override
  final LimitOrder order;
  @override
  final int attempt;
  final ReadProblem problem;

  const CancelUnverified(this.order, this.attempt, this.problem);

  @override
  bool operator ==(Object other) =>
      other is CancelUnverified &&
      identical(other.order, order) &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(CancelUnverified, order.id, attempt, problem);
}

/// The exchange reports the order cancelled.
final class CancelDone extends LimitCancelState {
  @override
  final LimitOrder order;
  @override
  final int attempt;

  const CancelDone(this.order, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is CancelDone &&
      identical(other.order, order) &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(CancelDone, order.id, attempt);
}

/// A call got HTTP 401: the flow ends its session. Terminal.
final class CancelSessionEnded extends LimitCancelState {
  @override
  final LimitOrder order;
  @override
  final int attempt;

  const CancelSessionEnded(this.order, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is CancelSessionEnded && other.attempt == attempt;

  @override
  int get hashCode => Object.hash(CancelSessionEnded, attempt);
}

/// What a cancel answered, closed.
@immutable
sealed class LimitCancelAnswer {
  const LimitCancelAnswer();
}

final class CancelAnsweredOrder extends LimitCancelAnswer {
  final LimitOrder order;

  const CancelAnsweredOrder(this.order);
}

final class CancelAnsweredGateRefused extends LimitCancelAnswer {
  final WriteGateRefusal refusal;

  const CancelAnsweredGateRefused(this.refusal);
}

/// Anything else: the cancel may or may not have taken effect.
final class CancelAnsweredUnsure extends LimitCancelAnswer {
  const CancelAnsweredUnsure();
}

final class CancelAnsweredSessionRejected extends LimitCancelAnswer {
  const CancelAnsweredSessionRejected();
}

@immutable
sealed class LimitCancelEvent {
  const LimitCancelEvent();
}

/// The user confirmed the cancel dialog.
final class CancelPressed extends LimitCancelEvent {
  const CancelPressed();
}

final class CancelAnswered extends LimitCancelEvent {
  final int attempt;
  final LimitCancelAnswer answer;

  const CancelAnswered(this.attempt, this.answer);
}

final class CancelChecked extends LimitCancelEvent {
  final int attempt;
  final Result<LimitOrder, ExchangeReadFailure> read;

  const CancelChecked(this.attempt, this.read);
}

final class CancelRetryPressed extends LimitCancelEvent {
  const CancelRetryPressed();
}

@immutable
sealed class LimitCancelEffect {
  const LimitCancelEffect();
}

/// Cancel [orderId] through the write gate; answer [CancelAnswered].
final class CancelSend extends LimitCancelEffect {
  final String orderId;
  final int attempt;

  const CancelSend(this.orderId, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is CancelSend &&
      other.orderId == orderId &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(CancelSend, orderId, attempt);
}

/// Read [orderId] again; answer [CancelChecked].
final class CancelRead extends LimitCancelEffect {
  final String orderId;
  final int attempt;

  const CancelRead(this.orderId, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is CancelRead &&
      other.orderId == orderId &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(CancelRead, orderId, attempt);
}

typedef LimitCancelNext = StepNext<LimitCancelState, LimitCancelEffect>;

LimitCancelNext _checking(LimitOrder order, int attempt) =>
    StepNext(CancelChecking(order, attempt), [CancelRead(order.id, attempt)]);

LimitCancelNext _settled(LimitOrder order, int attempt) =>
    order.status == LimitOrderStatus.cancelled
    ? StepNext(CancelDone(order, attempt))
    : StepNext(
        CancelIdle(order, attempt: attempt, problem: const CancelNotApplied()),
      );

/// Whether a cancel may be in flight: the page keeps Back as a stay.
bool limitCancelRunning(LimitCancelState state) => switch (state) {
  CancelSending() || CancelChecking() => true,
  CancelIdle() ||
  CancelUnverified() ||
  CancelDone() ||
  CancelSessionEnded() => false,
};

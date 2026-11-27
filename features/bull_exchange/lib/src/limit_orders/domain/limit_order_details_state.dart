import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'limit_order_cancel_event.dart';
import 'limit_order_cancel_state.dart';
import 'limit_order_details_effect.dart';
import 'limit_order_details_event.dart';

/// One limit order's details and its cancel: load → shown (with the cancel
/// step) → closed. Leaving says whether the order changed, so the list
/// that opened it reads again (LIM-3, LIM-5).
@immutable
sealed class LimitDetailsState {
  const LimitDetailsState();

  LimitDetailsNext next(LimitDetailsEvent event) {
    final state = this;
    if (event case DetailsSessionChanged(:final session)) {
      final current = _sessionOf(state);
      return current != null && current != session
          ? LimitDetailsNext(DetailsSessionEnded(changed: _changed(state)))
          : LimitDetailsNext.stay(state);
    }
    return switch ((state, event)) {
      (
        DetailsLoading(:final session, :final orderId, :final attempt),
        DetailsLoaded(attempt: final answered, :final read),
      )
          when answered == attempt =>
        switch (read) {
          Ok(value: final order) => LimitDetailsNext(
            DetailsShown(session, CancelIdle(order)),
          ),
          Err(failure: ExchangeSessionRejectedFailure()) =>
            const LimitDetailsNext(DetailsSessionEnded(changed: false)),
          Err(failure: ExchangeMissingFailure()) ||
          Err(failure: ExchangeUnreachableFailure()) ||
          Err(failure: ExchangeMalformedFailure()) => LimitDetailsNext(
            DetailsFailed(session, orderId, attempt, ReadProblem.of(read)!),
          ),
        },
      (DetailsLoading() || DetailsFailed(), DetailsBackPressed()) =>
        const LimitDetailsNext(DetailsClosed(changed: false)),
      (
        DetailsLoading(),
        DetailsLoaded() || DetailsRetryPressed() || DetailsCancelChanged(),
      ) =>
        LimitDetailsNext.stay(state),
      (
        DetailsFailed(:final session, :final orderId, :final attempt),
        DetailsRetryPressed(),
      ) =>
        LimitDetailsNext(DetailsLoading(session, orderId, attempt + 1), [
          DetailsRead(orderId, attempt + 1),
        ]),
      (DetailsFailed(), DetailsLoaded() || DetailsCancelChanged()) =>
        LimitDetailsNext.stay(state),
      (
        DetailsShown(:final session, :final cancel),
        DetailsCancelChanged(:final event),
      ) =>
        _stepped(state, cancel.next(event), cancel, session),
      (DetailsShown(:final session, :final cancel), DetailsRetryPressed()) =>
        _stepped(
          state,
          cancel.next(const CancelRetryPressed()),
          cancel,
          session,
        ),
      (DetailsShown(:final cancel), DetailsBackPressed()) =>
        limitCancelRunning(cancel)
            ? LimitDetailsNext.stay(state)
            : LimitDetailsNext(DetailsClosed(changed: _changed(state))),
      (DetailsShown(), DetailsLoaded()) => LimitDetailsNext.stay(state),
      (DetailsSessionEnded(:final changed), DetailsBackPressed()) =>
        LimitDetailsNext(DetailsClosed(changed: changed)),
      (
        DetailsSessionEnded(),
        DetailsLoaded() || DetailsRetryPressed() || DetailsCancelChanged(),
      ) =>
        LimitDetailsNext.stay(state),
      (
        DetailsClosed(),
        DetailsLoaded() ||
            DetailsRetryPressed() ||
            DetailsCancelChanged() ||
            DetailsBackPressed(),
      ) =>
        LimitDetailsNext.stay(state),
      (
        DetailsLoading() ||
            DetailsFailed() ||
            DetailsShown() ||
            DetailsSessionEnded() ||
            DetailsClosed(),
        DetailsSessionChanged(),
      ) =>
        LimitDetailsNext.stay(state),
    };
  }
}

final class DetailsLoading extends LimitDetailsState {
  final ExchangeSession session;
  final String orderId;
  final int attempt;

  const DetailsLoading(this.session, this.orderId, this.attempt);

  @override
  bool operator ==(Object other) =>
      other is DetailsLoading &&
      other.session == session &&
      other.orderId == orderId &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(DetailsLoading, session, orderId, attempt);
}

/// The read failed (or the order is not found); Retry reads again.
final class DetailsFailed extends LimitDetailsState {
  final ExchangeSession session;
  final String orderId;
  final int attempt;
  final ReadProblem problem;

  const DetailsFailed(this.session, this.orderId, this.attempt, this.problem);

  @override
  bool operator ==(Object other) =>
      other is DetailsFailed &&
      other.session == session &&
      other.orderId == orderId &&
      other.attempt == attempt &&
      other.problem == problem;

  @override
  int get hashCode =>
      Object.hash(DetailsFailed, session, orderId, attempt, problem);
}

final class DetailsShown extends LimitDetailsState {
  final ExchangeSession session;

  /// Never [CancelSessionEnded]: that ends the flow.
  final LimitCancelState cancel;

  const DetailsShown(this.session, this.cancel);

  LimitOrder get order => cancel.order;

  @override
  bool operator ==(Object other) =>
      other is DetailsShown &&
      other.session == session &&
      other.cancel == cancel;

  @override
  int get hashCode => Object.hash(DetailsShown, session, cancel);
}

/// The session the details opened with ended. The only exit is Close.
final class DetailsSessionEnded extends LimitDetailsState {
  final bool changed;

  const DetailsSessionEnded({required this.changed});

  @override
  bool operator ==(Object other) =>
      other is DetailsSessionEnded && other.changed == changed;

  @override
  int get hashCode => Object.hash(DetailsSessionEnded, changed);
}

/// The user left; [changed] when the order was cancelled here.
final class DetailsClosed extends LimitDetailsState {
  final bool changed;

  const DetailsClosed({required this.changed});

  @override
  bool operator ==(Object other) =>
      other is DetailsClosed && other.changed == changed;

  @override
  int get hashCode => Object.hash(DetailsClosed, changed);
}

typedef LimitDetailsNext = StepNext<LimitDetailsState, LimitDetailsEffect>;

/// The details of [orderId] for [session]; without one they have ended.
LimitDetailsNext limitDetailsStart(ExchangeSession? session, String orderId) =>
    switch (session) {
      final session? => LimitDetailsNext(DetailsLoading(session, orderId, 1), [
        DetailsRead(orderId, 1),
      ]),
      null => const LimitDetailsNext(DetailsSessionEnded(changed: false)),
    };

bool _changed(LimitDetailsState state) => switch (state) {
  DetailsShown(cancel: CancelDone()) => true,
  DetailsSessionEnded(:final changed) ||
  DetailsClosed(:final changed) => changed,
  DetailsShown() || DetailsLoading() || DetailsFailed() => false,
};

ExchangeSession? _sessionOf(LimitDetailsState state) => switch (state) {
  DetailsLoading(:final session) ||
  DetailsFailed(:final session) ||
  DetailsShown(:final session) => session,
  DetailsSessionEnded() || DetailsClosed() => null,
};

LimitDetailsNext _cancelNext(ExchangeSession session, LimitCancelNext next) =>
    switch (next.state) {
      // The cancel may have gone through: the list reads again.
      CancelSessionEnded() => LimitDetailsNext(
        const DetailsSessionEnded(changed: true),
      ),
      CancelIdle() ||
      CancelSending() ||
      CancelChecking() ||
      CancelUnverified() ||
      CancelDone() => LimitDetailsNext(DetailsShown(session, next.state), [
        for (final effect in next.effects) DetailsCancelEffect(effect),
      ]),
    };

LimitDetailsNext _stepped(
  LimitDetailsState state,
  LimitCancelNext next,
  LimitCancelState current,
  ExchangeSession session,
) => identical(next.state, current) && next.effects.isEmpty
    ? LimitDetailsNext.stay(state)
    : _cancelNext(session, next);

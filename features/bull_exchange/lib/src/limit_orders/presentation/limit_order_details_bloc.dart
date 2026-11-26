import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_cancel.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_details_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

/// The exchange calls of the details, bound to one session.
typedef LimitDetailsCalls = ({
  Future<ExchangeRead<LimitOrder>> Function(String orderId) read,
  Future<LimitCancelAnswer> Function(String orderId) cancel,
});

LimitDetailsCalls limitDetailsCallsOf(
  Exchange exchange,
  ExchangeSession session,
) => (
  read: (orderId) async => switch (await exchange.limitOrders.get(orderId)) {
    Ok(:final value) => ReadGot(value),
    Err(
      failure: ExchangeLimitOrderFailure(
        problem: ExchangeLimitOrderProblem.notFound,
      ),
    ) =>
      const ReadMissing(),
    Err(:final failure) => readOfExchangeFailure(failure),
  },
  cancel: (orderId) async {
    final gated = await exchange.writeGate.run(
      session,
      FinancialWriteKind.limitOrderCancel,
      () async => exchange.currentSession != session
          ? const Err<LimitOrder, ExchangeFailure>(
              ExchangeOperationStaleFailure(),
            )
          : await exchange.limitOrders.cancel(orderId),
    );
    return switch (gated) {
      GateRefused(:final refusal) => CancelAnsweredGateRefused(refusal),
      GateAdmitted(result: Ok(:final value)) => CancelAnsweredOrder(value),
      GateAdmitted(result: Err(failure: ExchangeSessionRejectedFailure())) =>
        const CancelAnsweredSessionRejected(),
      // Refused, lost or never sent: the re-read decides.
      GateAdmitted(result: Err()) => const CancelAnsweredUnsure(),
    };
  },
);

/// Shell of [transitionLimitDetails]: applies events one at a time, emits
/// the new state and runs its effects, each answer tagged with its attempt.
class LimitDetailsBloc extends Bloc<LimitDetailsEvent, LimitDetailsState> {
  LimitDetailsBloc({
    required LimitDetailsCalls Function(ExchangeSession session) calls,
    required ExchangeSession? session,
    required String orderId,
    required Stream<ExchangeAccess> accessChanges,
  }) : this._(
         session == null ? null : calls(session),
         accessChanges,
         limitDetailsStart(session, orderId),
       );

  LimitDetailsBloc._(
    this._calls,
    Stream<ExchangeAccess> accessChanges,
    LimitDetailsNext start,
  ) : super(start.state) {
    on<LimitDetailsEvent>(_onEvent, transformer: sequential());
    _access = accessChanges.listen((access) {
      if (!isClosed) add(DetailsSessionChanged(access.signedInSession));
    });
    _run(start.effects);
  }

  final LimitDetailsCalls? _calls;
  late final StreamSubscription<ExchangeAccess> _access;

  void _onEvent(LimitDetailsEvent event, Emitter<LimitDetailsState> emit) {
    final next = transitionLimitDetails(state, event);
    if (identical(next.state, state)) return;
    emit(next.state);
    _run(next.effects);
  }

  void _run(List<LimitDetailsEffect> effects) {
    final calls = _calls;
    if (calls == null) return;
    for (final effect in effects) {
      switch (effect) {
        case DetailsRead(:final orderId, :final attempt):
          _answer(calls.read(orderId).then((r) => DetailsLoaded(attempt, r)));
        case DetailsCancelEffect(
          effect: CancelSend(:final orderId, :final attempt),
        ):
          _answer(
            calls
                .cancel(orderId)
                .then((a) => DetailsCancelChanged(CancelAnswered(attempt, a))),
          );
        case DetailsCancelEffect(
          effect: CancelRead(:final orderId, :final attempt),
        ):
          _answer(
            calls
                .read(orderId)
                .then((r) => DetailsCancelChanged(CancelChecked(attempt, r))),
          );
      }
    }
  }

  void _answer(Future<LimitDetailsEvent> answer) {
    unawaited(
      answer.then((event) {
        if (!isClosed) add(event);
      }),
    );
  }

  @override
  Future<void> close() async {
    await _access.cancel();
    return super.close();
  }
}

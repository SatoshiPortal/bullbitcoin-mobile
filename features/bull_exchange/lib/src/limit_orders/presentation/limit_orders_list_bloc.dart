import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:bull_exchange/src/limit_orders/presentation/limit_orders_list.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

typedef LimitOrdersListCalls = ({
  Future<ExchangeRead<List<LimitOrder>>> Function() list,
  Future<LimitCancelAllAnswer> Function() cancelAll,
});

/// The list reads the current session's account; the cancel-all runs
/// through the write gate of [session] and is never sent for another one.
LimitOrdersListCalls limitOrdersListCallsOf(
  Exchange exchange,
  ExchangeSession? session,
) => (
  list: () async => readOfResult(await exchange.limitOrders.listActive()),
  cancelAll: () async {
    if (session == null) return const CancelAllSessionRejected();
    final gated = await exchange.writeGate.run(
      session,
      FinancialWriteKind.limitOrderCancel,
      () async => exchange.currentSession != session
          ? const Err<List<LimitOrder>, ExchangeFailure>(
              ExchangeOperationStaleFailure(),
            )
          : await exchange.limitOrders.cancelAll(),
    );
    return switch (gated) {
      GateRefused(:final refusal) => CancelAllGateRefused(refusal),
      GateAdmitted(result: Ok()) => const CancelAllDone(),
      GateAdmitted(result: Err(failure: ExchangeSessionRejectedFailure())) =>
        const CancelAllSessionRejected(),
      // Refused, lost or never sent: the list read after it decides.
      GateAdmitted(result: Err()) => const CancelAllUnsure(),
    };
  },
);

/// Shell of [transitionLimitOrdersList]. Limit-order notifications and the
/// dashboard's refresh requests are events.
class LimitOrdersListBloc
    extends Bloc<LimitOrdersListEvent, LimitOrdersListState> {
  LimitOrdersListBloc({
    required LimitOrdersListCalls calls,
    required Stream<Result<NotificationMessage, ExchangeFailure>> notifications,
    Stream<void>? refreshRequests,
  }) : _calls = calls,
       super(limitOrdersListStart.state) {
    on<LimitOrdersListEvent>(_onEvent, transformer: sequential());
    _notifications = notifications
        .where(
          (event) =>
              event is Ok<NotificationMessage, ExchangeFailure> &&
              event.value.kind == NotificationMessageKind.limitOrder,
        )
        .listen((_) => _refresh());
    _refreshes = refreshRequests?.listen((_) => _refresh());
    _run(limitOrdersListStart.effects);
  }

  final LimitOrdersListCalls _calls;
  late final StreamSubscription<Object?> _notifications;
  StreamSubscription<void>? _refreshes;

  void _refresh() {
    if (!isClosed) add(const ListRefreshRequested());
  }

  void _onEvent(
    LimitOrdersListEvent event,
    Emitter<LimitOrdersListState> emit,
  ) {
    final next = transitionLimitOrdersList(state, event);
    if (identical(next.state, state)) return;
    emit(next.state);
    _run(next.effects);
  }

  void _run(List<LimitOrdersListEffect> effects) {
    for (final effect in effects) {
      final Future<LimitOrdersListEvent> answer = switch (effect) {
        ListFetch(:final attempt) => _calls.list().then(
          (read) => ListLoaded(attempt, read),
        ),
        ListCancelAll(:final attempt) => _calls.cancelAll().then(
          (answer) => ListCancelAllAnswered(attempt, answer),
        ),
      };
      unawaited(
        answer.then((event) {
          if (!isClosed) add(event);
        }),
      );
    }
  }

  @override
  Future<void> close() async {
    await _notifications.cancel();
    await _refreshes?.cancel();
    return super.close();
  }
}

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:bull_exchange/src/payout/payout_requirements_runner.dart';
import 'package:bull_exchange/src/withdraw/domain/withdraw_flow.dart';
import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

/// The exchange calls of the withdraw flow, bound to one session.
typedef WithdrawFlowCalls = ({
  Future<ExchangeRead<WithdrawContext>> Function() loadContext,
  Future<ExchangeRead<double>> Function(Market market) rate,
  Future<OrderCreateAnswered<WithdrawRequest, WithdrawOrder>> Function(
    OrderSendCreate<WithdrawRequest> effect,
  )
  create,
  Future<ExchangeRead<WithdrawOrder>> Function(
    WithdrawRequest request,
    DateTime sentAt,
  )
  findCreated,
  Future<ConfirmAnswered<WithdrawConfirmTarget, WithdrawOrder>> Function(
    ConfirmSend<WithdrawConfirmTarget> effect,
  )
  confirm,
  Future<ExchangeRead<Order>> Function(String orderId) readOrder,
  PayoutRequirementsCalls requirements,
});

WithdrawFlowCalls withdrawFlowCallsOf(
  Exchange exchange,
  ExchangeSession session,
) {
  final orders = exchange.orders(session.environment);
  return (
    loadContext: () async {
      final summary = readOfResult(
        await exchange.getUserSummary(session.environment),
      );
      // A journal that can't be read leaves no entry to start from; the
      // write gate then refuses the confirm itself (JournalUnreadable).
      final entries = switch (await exchange.openUnknownWrites()) {
        Ok(:final value) => value,
        Err() => const <UnknownWrite>[],
      };
      return switch (summary) {
        ReadGot(:final value) => ReadGot(WithdrawContext(value, entries)),
        ReadMissing() => const ReadMissing(),
        ReadUnreachable(:final reason, :final isNetwork) => ReadUnreachable(
          reason,
          isNetwork: isNetwork,
        ),
        ReadSessionRejected(:final why) => ReadSessionRejected(why),
        ReadMalformed(:final reason) => ReadMalformed(reason),
      };
    },
    rate: (market) async =>
        switch (await exchange.limitOrders.getRate(market.currency.code)) {
          Ok(:final value) => ReadGot(value.indexPrice),
          Err(:final failure) => readOfExchangeFailure(failure),
        },
    create: (effect) => runOrderCreate(
      gate: exchange.writeGate,
      session: session,
      effect: effect,
      create: (request) {
        final payout = request.payout;
        return orders.placeWithdrawalOrder(
          fiatAmount: request.amount.fiat,
          recipientId: payout.recipientId,
          paymentProcessor: payout.paymentProcessor,
          securityQuestion: payout.interacAnswer?.question,
          securityAnswer: payout.interacAnswer?.answer,
        );
      },
      journalUnknown: (request) =>
          exchange.journalUnknownOrderCreate(session, request.journal),
    ),
    findCreated: (request, sentAt) async =>
        switch (await orders.getOrders(type: OrderType.withdraw)) {
          Ok(:final value) => switch (findCreatedOrder(
            request.journal,
            sentAt,
            value,
          )) {
            final WithdrawOrder order => ReadGot(order),
            _ => const ReadMissing(),
          },
          Err(:final failure) => readOfExchangeFailure(failure),
        },
    confirm: (effect) => runServerConfirm(
      gate: exchange.writeGate,
      session: session,
      policy: withdrawConfirmPolicy,
      effect: effect,
      confirm: (target) => orders.confirmWithdrawOrder(
        target.order.orderId,
        interacUpdate: _interacUpdate(target.recipient),
      ),
    ),
    readOrder: (orderId) async => readOfResult(await orders.getOrder(orderId)),
    requirements: payoutRequirementsCallsOf(exchange, session),
  );
}

/// The Interac answer saved on the recipient with the confirm: only when
/// the user asked to save it as the default.
({
  String recipientId,
  String email,
  String? securityQuestion,
  String? securityAnswer,
})?
_interacUpdate(ReadyRecipient recipient) {
  final evidence = recipient.interac;
  final details = recipient.chosen.recipient.details;
  if (evidence == null || details is! InteracEmailCadDetails) return null;
  final save = evidence.saveAsDefault;
  return (
    recipientId: recipient.chosen.recipient.recipientId,
    email: details.email,
    securityQuestion: save ? evidence.answer.question : null,
    securityAnswer: save ? evidence.answer.answer : null,
  );
}

/// Shell of [transitionWithdrawFlow]: applies events one at a time, emits the
/// new state and runs its effects. Every answer carries the attempt, ticket
/// or market that asked for it; the machine drops stale ones.
class WithdrawFlowBloc extends Bloc<WithdrawFlowEvent, WithdrawFlowState> {
  WithdrawFlowBloc({
    required WithdrawFlowCalls Function(ExchangeSession session) calls,
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
  }) : this._(
         session == null ? null : calls(session),
         accessChanges,
         withdrawFlowStart(session),
       );

  WithdrawFlowBloc._(
    this._calls,
    Stream<ExchangeAccess> accessChanges,
    WithdrawFlowNext start,
  ) : super(start.state) {
    on<WithdrawFlowEvent>(_onEvent, transformer: sequential());
    final calls = _calls;
    if (calls != null) {
      _requirements = PayoutRequirementsRunner(calls.requirements, (event) {
        if (!isClosed) add(WithdrawRequirementsChanged(event));
      });
    }
    _access = accessChanges.listen((access) {
      if (!isClosed) add(WithdrawSessionChanged(access.signedInSession));
    });
    _run(start.effects);
  }

  final WithdrawFlowCalls? _calls;
  PayoutRequirementsRunner? _requirements;
  late final StreamSubscription<ExchangeAccess> _access;

  /// When each create attempt was sent: the re-read after an unknown outcome
  /// matches orders created around it.
  final Map<int, DateTime> _sentAt = {};

  void _onEvent(WithdrawFlowEvent event, Emitter<WithdrawFlowState> emit) {
    final next = transitionWithdrawFlow(state, event);
    if (identical(next.state, state)) return;
    emit(next.state);
    _run(next.effects);
  }

  void _run(List<WithdrawFlowEffect> effects) {
    final calls = _calls;
    if (calls == null) return;
    for (final effect in effects) {
      switch (effect) {
        case WithdrawLoadContext(:final attempt):
          _answer(
            calls.loadContext().then((r) => WithdrawContextLoaded(attempt, r)),
          );
        case WithdrawFetchRate(:final market):
          _answer(
            calls
                .rate(market)
                .then(
                  (r) => WithdrawAmountChanged(AmountRateArrived(market, r)),
                ),
          );
        case WithdrawRequirementsEffect(:final effect):
          _requirements?.run([effect]);
        case WithdrawOrderEffect(:final effect):
          _order(calls, effect);
        case WithdrawConfirmEffect(:final effect):
          _confirm(calls, effect);
      }
    }
  }

  void _order(
    WithdrawFlowCalls calls,
    OrderStepEffect<WithdrawRequest> effect,
  ) {
    switch (effect) {
      case final OrderSendCreate<WithdrawRequest> send:
        _sentAt[send.attempt] = clock.now();
        _answer(calls.create(send).then(WithdrawOrderChanged.new));
      case OrderFindCreated(:final request, :final attempt):
        _answer(
          calls
              .findCreated(request, _sentAt[attempt] ?? clock.now())
              .then((r) => WithdrawOrderChanged(OrderFindAnswered(attempt, r))),
        );
      // A withdrawal order has no quote lock (withdrawOrderPolicy): the
      // step never asks for timers, refreshes or a release.
      case OrderStartLockTimer() ||
          OrderRefresh() ||
          OrderScheduleRefreshRetry() ||
          OrderStopTimers() ||
          OrderRelease():
        break;
    }
  }

  void _confirm(
    WithdrawFlowCalls calls,
    ServerConfirmEffect<WithdrawConfirmTarget> effect,
  ) {
    switch (effect) {
      case final ConfirmSend<WithdrawConfirmTarget> send:
        _answer(calls.confirm(send).then(WithdrawConfirmChanged.new));
      case ConfirmVerify(:final target, :final attempt):
        _answer(
          calls
              .readOrder(target.order.orderId)
              .then(
                (read) => WithdrawConfirmChanged(
                  ConfirmVerified(attempt, withdrawConfirmCheck(read)),
                ),
              ),
        );
    }
  }

  void _answer(Future<WithdrawFlowEvent> answer) {
    unawaited(
      answer.then((event) {
        if (!isClosed) add(event);
      }),
    );
  }

  @override
  Future<void> close() async {
    _requirements?.close();
    await _access.cancel();
    return super.close();
  }
}

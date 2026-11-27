import 'dart:async';

import 'package:bull_exchange/src/payin/spend_options_runner.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:bull_exchange/src/payin/outcome_watch_runner.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/payin/payin_spend_calls.dart';
import 'package:bull_exchange/src/payout/payout_requirements_runner.dart';
import 'package:bull_exchange/src/pay/presentation/pay_flow.dart';
import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

/// The exchange and wallet calls of the pay flow, bound to one session.
typedef PayFlowCalls = ({
  Future<ExchangeRead<PayContext>> Function() loadContext,
  Future<ExchangeRead<double>> Function(Market market) rate,
  Future<OrderCreateAnswered<PayRequest, Order>> Function(
    OrderSendCreate<PayRequest> effect,
  )
  create,
  Future<ExchangeRead<Order>> Function(PayRequest request, DateTime sentAt)
  findCreated,
  Future<ExchangeRead<Order>> Function(Order order) refresh,
  PayoutRequirementsCalls requirements,
  PayinCalls payin,
  SpendOptionsCalls spend,
  ExchangeWriteGate gate,
});

PayFlowCalls payFlowCallsOf(
  Exchange exchange,
  ExchangeSession session,
  PayinWalletServices wallets,
) {
  final orders = exchange.orders(session.environment);
  return (
    loadContext: () async {
      final summary = readOfResult(
        await exchange.getUserSummary(session.environment),
      );
      final entries = switch (await exchange.openUnknownWrites()) {
        Ok(:final value) => value,
        Err() => const <UnknownWrite>[],
      };
      return switch (summary) {
        ReadGot(:final value) => ReadGot(PayContext(value, entries)),
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
      create: (request) async {
        // BBX currently prepares credentials/transport after this callback.
        // Until that owner can check the attempt at dispatch, refuse here.
        if (request.source case PayinFromAppWallet(witness: _?)) {
          return const WriteNotSent(ExchangeNotSentReason.sessionChanged);
        }
        return orders.placePayOrder(
          orderAmount: FiatAmount(request.amount.fiat),
          recipientId: request.payout.recipientId,
          network: request.source.rail,
          paymentDescription: request.amount.description.isEmpty
              ? null
              : request.amount.description,
          paymentProcessor: request.payout.paymentProcessor,
          usePayjoin: await _payjoinAsked(wallets, request.source),
          securityQuestion: request.payout.interacAnswer?.question,
          securityAnswer: request.payout.interacAnswer?.answer,
        );
      },
      journalUnknown: (request) =>
          exchange.journalUnknownOrderCreate(session, request.journal),
    ),
    findCreated: (request, sentAt) async =>
        switch (await orders.getOrders(type: request.journal.type)) {
          Ok(:final value) => switch (findCreatedOrder(
            request.journal,
            sentAt,
            value,
          )) {
            final order? => ReadGot(order),
            null => const ReadMissing(),
          },
          Err(:final failure) => readOfExchangeFailure(failure),
        },
    refresh: (order) async =>
        readOfResult(await orders.refreshPayOrder(order.orderId)),
    requirements: payoutRequirementsCallsOf(exchange, session),
    payin: payinCallsOf(exchange, session, wallets),
    spend: spendOptionsCallsOf(session, wallets),
    gate: exchange.writeGate,
  );
}

/// The order asks the exchange for a payjoin URI only for an on-chain payin
/// from an app wallet, and only when the account's setting allows it.
Future<bool> _payjoinAsked(
  PayinWalletServices wallets,
  PayinSource source,
) async {
  if (source case PayinFromAppWallet(rail: BtcNetwork.bitcoin)) {
    return switch (await wallets.payjoinPolicy.load()) {
      Ok(:final value) => value.sellEnabled,
      Err() => false,
    };
  }
  return false;
}

/// Shell of [transitionPayFlow]: applies events one at a time, emits the
/// new state and runs its effects. Every answer carries the attempt, order
/// id or ticket that asked for it; the machine drops stale ones.
class PayFlowBloc extends Bloc<PayFlowEvent, PayFlowState> {
  PayFlowBloc({
    required PayFlowCalls Function(ExchangeSession session) calls,
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
  }) : this._(
         session,
         session == null ? null : calls(session),
         accessChanges,
         payFlowStart(session),
       );

  PayFlowBloc._(
    ExchangeSession? session,
    this._calls,
    Stream<ExchangeAccess> accessChanges,
    PayFlowNext start,
  ) : super(start.state) {
    on<PayFlowEvent>(_onEvent, transformer: sequential());
    final calls = _calls;
    if (calls != null && session != null) {
      _requirements = PayoutRequirementsRunner(calls.requirements, (event) {
        if (!isClosed) add(PayRequirementsChanged(event));
      });
      _payin = PayinRunner(calls.payin, calls.gate, session, (event) {
        if (!isClosed) add(PayPayinChanged(event));
      });
      _spend = SpendOptionsRunner(calls.spend, (event) {
        if (!isClosed) add(PaySpendChanged(event));
      });
      _receipt = OutcomeWatchRunner(calls.payin.readOrder, (event) {
        if (!isClosed) add(PayReceiptChanged(event));
      });
    }
    _access = accessChanges.listen((access) {
      if (!isClosed) add(PaySessionChanged(access.signedInSession));
    });
    _run(start.effects);
  }

  final PayFlowCalls? _calls;
  PayoutRequirementsRunner? _requirements;
  PayinRunner? _payin;
  SpendOptionsRunner? _spend;
  OutcomeWatchRunner<Order>? _receipt;
  late final StreamSubscription<ExchangeAccess> _access;
  final Map<int, DateTime> _sentAt = {};
  final Map<String, Timer> _quoteTimers = {};
  PayinWalletAttempt? _walletAttempt;

  void _onEvent(PayFlowEvent event, Emitter<PayFlowState> emit) {
    var admitted = event;
    if (state is PaySource && event is PaySourcePicked) {
      if (event.source case final PayinFromAppWallet source) {
        final bound = source.bindAttempt();
        if (bound == null) return;
        _walletAttempt?.retire();
        _walletAttempt = bound.attempt;
        if (bound.attempt != null) _payin?.useWitnessedWallet();
        admitted = PaySourcePicked(bound);
      } else {
        _walletAttempt?.retire();
        _walletAttempt = null;
      }
    }
    final next = transitionPayFlow(state, admitted);
    if (next.state is PayClosed ||
        next.state is PaySessionEnded ||
        (next.state is PaySource && state is! PaySource)) {
      _walletAttempt?.retire();
      _walletAttempt = null;
    }
    if (identical(next.state, state) && next.effects.isEmpty) return;
    if (!identical(next.state, state)) emit(next.state);
    _run(next.effects);
  }

  void _run(List<PayFlowEffect> effects) {
    final calls = _calls;
    if (calls == null) return;
    for (final effect in effects) {
      switch (effect) {
        case PayLoadContext(:final attempt):
          _answer(
            calls.loadContext().then((r) => PayContextLoaded(attempt, r)),
          );
        case PayReloadForDetour():
          _answer(calls.loadContext().then(PayDetourLoaded.new));
        case PayFetchRate(:final market):
          _answer(
            calls
                .rate(market)
                .then((r) => PayAmountChanged(AmountRateArrived(market, r))),
          );
        case PayRequirementsEffect(:final effect):
          _requirements?.run([effect]);
        case PayOrderEffect(:final effect):
          _order(calls, effect);
        case PayPayinEffect(:final effect):
          _payin?.run([effect]);
        case PaySpendEffect(:final effect):
          _spend?.run([effect]);
        case PayReceiptEffect(:final effect):
          _receipt?.run(effect);
      }
    }
  }

  Order? get _quotedOrder => switch (state) {
    PayOrdering(order: OrderQuoted(:final quoted)) => quoted.order,
    PayLoading() ||
    PayRecipient() ||
    PayRequirements() ||
    PayAmount() ||
    PaySource() ||
    PayOrdering() ||
    PayPaying() ||
    PayDone() ||
    PaySessionEnded() ||
    PayClosed() => null,
  };

  void _order(PayFlowCalls calls, OrderStepEffect<PayRequest> effect) {
    switch (effect) {
      case final OrderSendCreate<PayRequest> send:
        _sentAt[send.attempt] = clock.now();
        _answer(calls.create(send).then(PayOrderChanged.new));
      case OrderFindCreated(:final request, :final attempt):
        _answer(
          calls
              .findCreated(request, _sentAt[attempt] ?? clock.now())
              .then((r) => PayOrderChanged(OrderFindAnswered(attempt, r))),
        );
      case OrderStartLockTimer(:final orderId):
        // The quote holds until the order's payment deadline.
        final deadline = _quotedOrder?.confirmationDeadline;
        if (deadline == null) break;
        final left = deadline.difference(clock.now());
        _arm(
          orderId,
          left.isNegative ? Duration.zero : left,
          () => OrderLockDue<PayRequest, Order>(orderId),
        );
      case OrderRefresh(:final orderId):
        final order = switch (state) {
          PayOrdering(order: OrderQuoted(:final quoted)) => quoted.order,
          PayPaying(:final quoted) => quoted.order,
          PayLoading() ||
          PayRecipient() ||
          PayRequirements() ||
          PayAmount() ||
          PaySource() ||
          PayOrdering() ||
          PayDone() ||
          PaySessionEnded() ||
          PayClosed() => null,
        };
        if (order == null || order.orderId != orderId) break;
        _answer(
          calls
              .refresh(order)
              .then((r) => PayOrderChanged(OrderRefreshed(orderId, r))),
        );
      case OrderScheduleRefreshRetry(:final orderId):
        _arm(
          orderId,
          const Duration(seconds: 5),
          () => OrderRetryDue<PayRequest, Order>(orderId),
        );
      case OrderStopTimers(:final orderId):
        _quoteTimers.remove(orderId)?.cancel();
      // Nothing to release: an unpaid order lapses at its deadline.
      case OrderRelease():
        break;
    }
  }

  void _arm(
    String orderId,
    Duration after,
    OrderStepEvent<PayRequest, Order> Function() event,
  ) {
    _quoteTimers.remove(orderId)?.cancel();
    _quoteTimers[orderId] = Timer(after, () {
      _quoteTimers.remove(orderId);
      if (!isClosed) add(PayOrderChanged(event()));
    });
  }

  void _answer(Future<PayFlowEvent> answer) {
    unawaited(
      answer.then((event) {
        if (!isClosed) add(event);
      }),
    );
  }

  @override
  Future<void> close() async {
    _walletAttempt?.retire();
    _requirements?.close();
    _payin?.close();
    _spend?.close();
    _receipt?.close();
    for (final timer in _quoteTimers.values) {
      timer.cancel();
    }
    _quoteTimers.clear();
    await _access.cancel();
    return super.close();
  }
}

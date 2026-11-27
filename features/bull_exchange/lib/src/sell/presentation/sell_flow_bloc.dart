import 'dart:async';

import 'package:bull_exchange/src/payin/spend_options_runner.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/payin/payin_spend_calls.dart';
import 'package:bull_exchange/src/payout/payout_requirements_runner.dart';
import 'package:bull_exchange/src/sell/presentation/sell_flow.dart';
import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

/// The exchange and wallet calls of the sell flow, bound to one session.
typedef SellFlowCalls = ({
  Future<ExchangeRead<SellContext>> Function() loadContext,
  Future<ExchangeRead<double>> Function(Market market) rate,
  Future<OrderCreateAnswered<SellRequest, Order>> Function(
    OrderSendCreate<SellRequest> effect,
  )
  create,
  Future<ExchangeRead<Order>> Function(SellRequest request, DateTime sentAt)
  findCreated,
  Future<ExchangeRead<Order>> Function(Order order) refresh,
  PayoutRequirementsCalls requirements,
  PayinCalls payin,
  SpendOptionsCalls spend,
  ExchangeWriteGate gate,
});

SellFlowCalls sellFlowCallsOf(
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
        ReadGot(:final value) => ReadGot(SellContext(value, entries)),
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
        if (request.source case PayinFromAppWallet(witness: _?)) {
          return const WriteNotSent(ExchangeNotSentReason.sessionChanged);
        }
        final usePayjoin = await _payjoinAsked(wallets, request.source);
        return switch (request.payout) {
          SellToBalance() => orders.placeSellOrder(
            orderAmount: request.orderAmount,
            currency: request.amount.market.currency,
            network: request.source.rail,
            usePayjoin: usePayjoin,
          ),
          SellToRecipient(:final recipient) => orders.placePayOrder(
            orderAmount: request.orderAmount,
            recipientId: recipient.orderParams.recipientId,
            network: request.source.rail,
            paymentProcessor: recipient.orderParams.paymentProcessor,
            usePayjoin: usePayjoin,
            securityQuestion: recipient.orderParams.interacAnswer?.question,
            securityAnswer: recipient.orderParams.interacAnswer?.answer,
          ),
        };
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
    refresh: (order) async {
      if (order is FiatPaymentOrder) {
        return readOfResult(await orders.refreshPayOrder(order.orderId));
      }
      if (order is SellOrder) {
        return readOfResult(await orders.refreshSellOrder(order.orderId));
      }
      return readOfResult(await orders.getOrder(order.orderId));
    },
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

/// Shell of [transitionSellFlow]: applies events one at a time, emits the
/// new state and runs its effects. Every answer carries the attempt, order
/// id or ticket that asked for it; the machine drops stale ones.
class SellFlowBloc extends Bloc<SellFlowEvent, SellFlowState> {
  SellFlowBloc({
    required SellFlowCalls Function(ExchangeSession session) calls,
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
  }) : this._(
         session,
         session == null ? null : calls(session),
         accessChanges,
         sellFlowStart(session),
       );

  SellFlowBloc._(
    ExchangeSession? session,
    this._calls,
    Stream<ExchangeAccess> accessChanges,
    SellFlowNext start,
  ) : super(start.state) {
    on<SellFlowEvent>(_onEvent, transformer: sequential());
    final calls = _calls;
    if (calls != null && session != null) {
      _requirements = PayoutRequirementsRunner(calls.requirements, (event) {
        if (!isClosed) add(SellRequirementsChanged(event));
      });
      _payin = PayinRunner(calls.payin, calls.gate, session, (event) {
        if (!isClosed) add(SellPayinChanged(event));
      });
      _spend = SpendOptionsRunner(calls.spend, (event) {
        if (!isClosed) add(SellSpendChanged(event));
      });
    }
    _access = accessChanges.listen((access) {
      if (!isClosed) add(SellSessionChanged(access.signedInSession));
    });
    _run(start.effects);
  }

  final SellFlowCalls? _calls;
  PayoutRequirementsRunner? _requirements;
  PayinRunner? _payin;
  SpendOptionsRunner? _spend;
  late final StreamSubscription<ExchangeAccess> _access;
  final Map<int, DateTime> _sentAt = {};
  final Map<String, Timer> _quoteTimers = {};
  PayinWalletAttempt? _walletAttempt;

  void _onEvent(SellFlowEvent event, Emitter<SellFlowState> emit) {
    var admitted = event;
    if (state is SellSource && event is SellSourcePicked) {
      if (event.source case final PayinFromAppWallet source) {
        final bound = source.bindAttempt();
        if (bound == null) return;
        _walletAttempt?.retire();
        _walletAttempt = bound.attempt;
        if (bound.attempt != null) _payin?.useWitnessedWallet();
        admitted = SellSourcePicked(bound);
      } else {
        _walletAttempt?.retire();
        _walletAttempt = null;
      }
    }
    final next = transitionSellFlow(state, admitted);
    if (next.state is SellClosed ||
        next.state is SellSessionEnded ||
        (next.state is SellSource && state is! SellSource)) {
      _walletAttempt?.retire();
      _walletAttempt = null;
    }
    if (identical(next.state, state) && next.effects.isEmpty) return;
    if (!identical(next.state, state)) emit(next.state);
    _run(next.effects);
  }

  void _run(List<SellFlowEffect> effects) {
    final calls = _calls;
    if (calls == null) return;
    for (final effect in effects) {
      switch (effect) {
        case SellLoadContext(:final attempt):
          _answer(
            calls.loadContext().then((r) => SellContextLoaded(attempt, r)),
          );
        case SellReloadForDetour():
          _answer(calls.loadContext().then(SellDetourLoaded.new));
        case SellFetchRate(:final market):
          _answer(
            calls
                .rate(market)
                .then((r) => SellAmountChanged(AmountRateArrived(market, r))),
          );
        case SellRequirementsEffect(:final effect):
          _requirements?.run([effect]);
        case SellOrderEffect(:final effect):
          _order(calls, effect);
        case SellPayinEffect(:final effect):
          _payin?.run([effect]);
        case SellSpendEffect(:final effect):
          _spend?.run([effect]);
      }
    }
  }

  Order? get _quotedOrder => switch (state) {
    SellOrdering(order: OrderQuoted(:final quoted)) => quoted.order,
    SellLoading() ||
    SellAmount() ||
    SellSource() ||
    SellPayoutPick() ||
    SellRecipient() ||
    SellRequirements() ||
    SellOrdering() ||
    SellPaying() ||
    SellDone() ||
    SellSessionEnded() ||
    SellClosed() => null,
  };

  void _order(SellFlowCalls calls, OrderStepEffect<SellRequest> effect) {
    switch (effect) {
      case final OrderSendCreate<SellRequest> send:
        _sentAt[send.attempt] = clock.now();
        _answer(calls.create(send).then(SellOrderChanged.new));
      case OrderFindCreated(:final request, :final attempt):
        _answer(
          calls
              .findCreated(request, _sentAt[attempt] ?? clock.now())
              .then((r) => SellOrderChanged(OrderFindAnswered(attempt, r))),
        );
      case OrderStartLockTimer(:final orderId):
        // The quote holds until the order's payment deadline.
        final deadline = _quotedOrder?.confirmationDeadline;
        if (deadline == null) break;
        final left = deadline.difference(clock.now());
        _arm(
          orderId,
          left.isNegative ? Duration.zero : left,
          () => OrderLockDue<SellRequest, Order>(orderId),
        );
      case OrderRefresh(:final orderId):
        final order = switch (state) {
          SellOrdering(order: OrderQuoted(:final quoted)) => quoted.order,
          SellPaying(:final quoted) => quoted.order,
          SellLoading() ||
          SellAmount() ||
          SellSource() ||
          SellPayoutPick() ||
          SellRecipient() ||
          SellRequirements() ||
          SellOrdering() ||
          SellDone() ||
          SellSessionEnded() ||
          SellClosed() => null,
        };
        if (order == null || order.orderId != orderId) break;
        _answer(
          calls
              .refresh(order)
              .then((r) => SellOrderChanged(OrderRefreshed(orderId, r))),
        );
      case OrderScheduleRefreshRetry(:final orderId):
        _arm(
          orderId,
          const Duration(seconds: 5),
          () => OrderRetryDue<SellRequest, Order>(orderId),
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
    OrderStepEvent<SellRequest, Order> Function() event,
  ) {
    _quoteTimers.remove(orderId)?.cancel();
    _quoteTimers[orderId] = Timer(after, () {
      _quoteTimers.remove(orderId);
      if (!isClosed) add(SellOrderChanged(event()));
    });
  }

  void _answer(Future<SellFlowEvent> answer) {
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
    for (final timer in _quoteTimers.values) {
      timer.cancel();
    }
    _quoteTimers.clear();
    await _access.cancel();
    return super.close();
  }
}

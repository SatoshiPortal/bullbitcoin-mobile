import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/buy/domain/buy_flow.dart';
import 'package:bull_exchange/src/buy/domain/buy_payjoin.dart';
import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:bull_exchange/src/exchange_payout_wallets.dart';
import 'package:bull_exchange/src/payin/outcome_watch_runner.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

/// The app services the buy flow reaches beyond the exchange: the payout
/// wallets, the payjoin receiver, and the wallet effects of a settled
/// payout.
typedef BuyWalletServices = ({
  ExchangePayoutWallets payouts,
  PayjoinSessions payjoinSessions,
  PayjoinReceiver payjoinReceiver,
  PayjoinPolicyAccess payjoinPolicy,
  Future<void> Function(String walletId) pollWallet,
  Future<void> Function(List<Order> orders) labelOrders,
  Future<String?> Function(String raw) validateBitcoinAddress,
});

/// The calls of the buy flow, bound to one session.
typedef BuyFlowCalls = ({
  Future<ExchangeRead<BuyContext>> Function() loadContext,
  Future<ExchangeRead<double>> Function(Market market) rate,
  Future<Result<Destination, Failure>> Function(
    DestinationOptionAppWallet option,
  )
  receiveAddress,
  Future<Result<Destination, Failure>> Function(String text) validateAddress,
  Future<OrderCreateAnswered<BuyRequest, BuyOrder>> Function(
    OrderSendCreate<BuyRequest> effect,
  )
  create,
  Future<ExchangeRead<BuyOrder>> Function(BuyRequest request, DateTime sentAt)
  findCreated,
  Future<ExchangeRead<BuyOrder>> Function(String orderId) refresh,
  Future<ConfirmAnswered<BuyConfirmTarget, BuyOrder>> Function(
    ConfirmSend<BuyConfirmTarget> effect,
  )
  confirm,
  Future<ExchangeRead<Order>> Function(String orderId) readOrder,
  Future<ExchangeRead<BuyOrder>> Function(String orderId) watchOrder,
  Future<void> Function(BuyOrder order) release,
  Future<void> Function(BuyOrder order, String? walletId) settled,
});

BuyFlowCalls buyFlowCallsOf(
  Exchange exchange,
  ExchangeSession session,
  BuyWalletServices services,
) {
  final orders = exchange.orders(session.environment);
  final bitcoin = BitcoinNetwork.fromName(session.environment.name);
  final liquid = LiquidNetwork.fromName(session.environment.name);
  // The wallets offered, by id: a receive address is only ever read from a
  // wallet the flow listed.
  final registrations = <String, WalletRegistration>{};
  // The payjoin URI each create attached, by order and by request: some
  // replies don't echo it, and the done page and the release read it.
  final bip21ByOrder = <String, String>{};
  final bip21ByRequest = <BuyRequest, String>{};

  BuyOrder withBip21(BuyOrder order) {
    final bip21 = bip21ByOrder[order.orderId];
    return bip21 != null && order.bip21URI == null
        ? order.copyWith(bip21URI: bip21)
        : order;
  }

  ExchangeRead<BuyOrder> buyOrderOf(ExchangeRead<Order> read) => switch (read) {
    ReadGot(value: final BuyOrder order) => ReadGot(withBip21(order)),
    ReadGot() => const ReadMalformed('not a buy order'),
    ReadMissing() => const ReadMissing(),
    ReadUnreachable(:final reason, :final isNetwork) => ReadUnreachable(
      reason,
      isNetwork: isNetwork,
    ),
    ReadSessionRejected(:final why) => ReadSessionRejected(why),
    ReadMalformed(:final reason) => ReadMalformed(reason),
  };

  Future<List<BuyPayoutWallet>?> wallets() async {
    final listed = <BuyPayoutWallet>[];
    for (final network in <Network>[bitcoin, liquid]) {
      switch (await services.payouts.walletsForNetwork(network)) {
        case Ok(:final value):
          for (final wallet in value.wallets) {
            if (wallet.network != network) continue;
            registrations[wallet.id] = wallet;
            listed.add(
              BuyPayoutWallet(
                walletId: wallet.id,
                rail: network is LiquidNetwork
                    ? BtcNetwork.liquid
                    : BtcNetwork.bitcoin,
                label: wallet.label,
                isDefault: wallet.isDefault,
                canPayjoin:
                    network is BitcoinNetwork &&
                    wallet.signer == WalletSigner.local,
              ),
            );
          }
        case Err():
          return null;
      }
    }
    return listed;
  }

  return (
    loadContext: () async {
      final summary = readOfResult(
        await exchange.getUserSummary(session.environment),
      );
      final listed = await wallets();
      final payjoinAllowed = switch (await services.payjoinPolicy.load()) {
        Ok(:final value) => value.buyEnabled,
        Err() => false,
      };
      // A journal that can't be read leaves no entry to start from; the
      // write gate then refuses the confirm itself (JournalUnreadable).
      final entries = switch (await exchange.openUnknownWrites()) {
        Ok(:final value) => value,
        Err() => const <UnknownWrite>[],
      };
      if (listed == null) {
        return const ReadUnreachable('payout wallets', isNetwork: false);
      }
      return switch (summary) {
        ReadGot(:final value) => ReadGot(
          BuyContext(
            summary: value,
            wallets: listed,
            payjoinAllowed: payjoinAllowed,
            openEntries: entries,
          ),
        ),
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
    receiveAddress: (option) async {
      final wallet = registrations[option.walletId];
      final address = wallet == null
          ? null
          : await services.payouts.receive(wallet, advance: false);
      return address == null
          ? const Err(BuyReceiveAddressUnavailable())
          : Ok(DestinationAppWallet(option.walletId, option.rail, address));
    },
    validateAddress: (text) async =>
        switch (await services.validateBitcoinAddress(text)) {
          final address? => Ok(DestinationAddress(BtcNetwork.bitcoin, address)),
          null => const Err(BuyAddressInvalid()),
        },
    create: (effect) async {
      BuyPayjoinReceiver? receiver;
      final answer = await runOrderCreate<BuyRequest, BuyOrder>(
        gate: exchange.writeGate,
        session: session,
        effect: effect,
        create: (request) async {
          final walletId = request.payjoinWalletId;
          if (walletId != null) {
            receiver = await startBuyPayjoin(
              services.payjoinReceiver,
              walletId: walletId,
              network: bitcoin,
              address: request.destination.address,
              amountSat: request.amount.sats,
            );
          }
          return orders.placeBuyOrder(
            toAddress: request.destination.address,
            orderAmount: request.orderAmount,
            currency: request.currency,
            network: request.network,
            isOwner: true,
            payjoinBip21: receiver?.bip21,
          );
        },
        journalUnknown: (request) =>
            exchange.journalUnknownOrderCreate(session, request.journal),
      );
      final attached = receiver;
      if (attached == null) return answer;
      switch (answer.answer) {
        case GateAdmitted(result: WriteDone(:final value)):
          bip21ByOrder[value.orderId] = attached.bip21;
          return OrderCreateAnswered(
            answer.attempt,
            GateAdmitted(WriteDone(withBip21(value))),
          );
        // The order may exist and pay through this receiver.
        case GateAdmitted(result: WriteOutcomeUnknown()):
          bip21ByRequest[effect.request] = attached.bip21;
          return answer;
        case GateAdmitted(
              result: WriteRefused() ||
                  WriteNotSent() ||
                  WriteSessionRejected(),
            ) ||
            GateRefused():
          await dropBuyPayjoin(services.payjoinReceiver, attached.id);
          return answer;
      }
    },
    findCreated: (request, sentAt) async {
      switch (await orders.getOrders(type: OrderType.buy)) {
        case Ok(:final value):
          final found = findCreatedOrder(request.journal, sentAt, value);
          if (found is! BuyOrder) return const ReadMissing();
          if (bip21ByRequest[request] case final bip21?) {
            bip21ByOrder[found.orderId] = bip21;
          }
          return ReadGot(withBip21(found));
        case Err(:final failure):
          return readOfExchangeFailure(failure);
      }
    },
    refresh: (orderId) async =>
        switch (readOfResult(await orders.refreshBuyOrder(orderId))) {
          ReadGot(:final value) => ReadGot(withBip21(value)),
          final other => other,
        },
    confirm: (effect) => runServerConfirm(
      gate: exchange.writeGate,
      session: session,
      policy: buyConfirmPolicy,
      effect: effect,
      confirm: (target) async =>
          switch (await orders.confirmBuyOrder(target.order.orderId)) {
            WriteDone(:final value) => WriteDone(withBip21(value)),
            final other => other,
          },
    ),
    readOrder: (orderId) async => readOfResult(await orders.getOrder(orderId)),
    watchOrder: (orderId) async =>
        buyOrderOf(readOfResult(await orders.getOrder(orderId))),
    release: (order) => releaseBuyPayjoin(
      services.payjoinSessions,
      services.payjoinReceiver,
      withBip21(order),
    ),
    settled: (order, walletId) async {
      // Only an order that completed may write the privileged exchange
      // labels (#2624).
      if (order.orderStatus == OrderStatus.completed) {
        await services.labelOrders([order]);
      }
      if (walletId != null) unawaited(services.pollWallet(walletId));
    },
  );
}

/// Shell of [transitionBuyFlow]: applies events one at a time, emits the
/// new state and runs its effects. Every answer carries the attempt, order
/// id, option, text or ticket that asked for it; the machine drops stale
/// ones.
class BuyFlowBloc extends Bloc<BuyFlowEvent, BuyFlowState> {
  BuyFlowBloc({
    required BuyFlowCalls Function(ExchangeSession session) calls,
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
    Duration refreshRetryAfter = const Duration(seconds: 5),
  }) : this._(
         session == null ? null : calls(session),
         accessChanges,
         buyFlowStart(session),
         refreshRetryAfter,
       );

  BuyFlowBloc._(
    this._calls,
    Stream<ExchangeAccess> accessChanges,
    BuyFlowNext start,
    this._refreshRetryAfter,
  ) : super(start.state) {
    on<BuyFlowEvent>(_onEvent, transformer: sequential());
    final calls = _calls;
    if (calls != null) {
      _watch = OutcomeWatchRunner(calls.watchOrder, (event) {
        if (!isClosed) add(BuyWatchChanged(event));
      });
    }
    _access = accessChanges.listen((access) {
      if (!isClosed) add(BuySessionChanged(access.signedInSession));
    });
    _run(start.effects, start.state);
  }

  final BuyFlowCalls? _calls;
  final Duration _refreshRetryAfter;
  OutcomeWatchRunner<BuyOrder>? _watch;
  late final StreamSubscription<ExchangeAccess> _access;
  final Map<String, Timer> _locks = {};
  final Map<String, Timer> _retries = {};

  /// When each create attempt was sent: the re-read after an unknown outcome
  /// matches orders created around it.
  final Map<int, DateTime> _sentAt = {};

  void _onEvent(BuyFlowEvent event, Emitter<BuyFlowState> emit) {
    final before = state;
    final next = transitionBuyFlow(before, event);
    if (identical(next.state, before) && next.effects.isEmpty) return;
    if (!identical(next.state, before)) emit(next.state);
    _run(next.effects, before);
  }

  /// Runs [effects]; [before] is the state that left, for the order an
  /// effect names.
  void _run(List<BuyFlowEffect> effects, BuyFlowState before) {
    final calls = _calls;
    if (calls == null) return;
    for (final effect in effects) {
      switch (effect) {
        case BuyLoadContext(:final attempt):
          _answer(
            calls.loadContext().then((r) => BuyContextLoaded(attempt, r)),
          );
        case BuyReloadForDetour():
          _answer(calls.loadContext().then(BuyDetourLoaded.new));
        case BuyFetchRate(:final market):
          _answer(
            calls
                .rate(market)
                .then((r) => BuyAmountChanged(AmountRateArrived(market, r))),
          );
        case BuyDestinationEffect(:final effect):
          _destination(calls, effect);
        case BuyOrderEffect(:final effect):
          _order(calls, effect, before);
        case BuyConfirmEffect(:final effect):
          _confirm(calls, effect);
        case BuyWatchEffect(:final effect):
          _watch?.run(effect);
        case BuyPayoutSettled(:final order, :final walletId):
          unawaited(calls.settled(order, walletId));
      }
    }
  }

  void _destination(BuyFlowCalls calls, PickEffect<DestinationOption> effect) {
    switch (effect) {
      case PickResolve(option: final DestinationOptionAppWallet option):
        _answer(
          calls
              .receiveAddress(option)
              .then((r) => BuyDestinationChanged(PickResolved(option, r))),
        );
      // Buy offers no exchange default wallet (bd t-54y).
      case PickResolve(option: DestinationOptionDefaultWallet()):
        break;
      case PickValidate(:final text):
        _answer(
          calls
              .validateAddress(text)
              .then((r) => BuyDestinationChanged(PickValidated(text, r))),
        );
    }
  }

  void _order(
    BuyFlowCalls calls,
    OrderStepEffect<BuyRequest> effect,
    BuyFlowState before,
  ) {
    switch (effect) {
      case final OrderSendCreate<BuyRequest> send:
        _sentAt[send.attempt] = clock.now();
        _answer(calls.create(send).then(BuyOrderChanged.new));
      case OrderFindCreated(:final request, :final attempt):
        _answer(
          calls
              .findCreated(request, _sentAt[attempt] ?? clock.now())
              .then((r) => BuyOrderChanged(OrderFindAnswered(attempt, r))),
        );
      case OrderStartLockTimer(:final orderId):
        _locks.remove(orderId)?.cancel();
        final current = state;
        final deadline =
            current is BuyReview && current.order.orderId == orderId
            ? current.order.confirmationDeadline
            : null;
        if (deadline == null) break;
        final wait = deadline.difference(clock.now());
        _locks[orderId] = Timer(wait.isNegative ? Duration.zero : wait, () {
          if (!isClosed) add(BuyOrderChanged(OrderLockDue(orderId)));
        });
      case OrderRefresh(:final orderId):
        _answer(
          calls
              .refresh(orderId)
              .then((r) => BuyOrderChanged(OrderRefreshed(orderId, r))),
        );
      case OrderScheduleRefreshRetry(:final orderId):
        _retries.remove(orderId)?.cancel();
        _retries[orderId] = Timer(_refreshRetryAfter, () {
          if (!isClosed) add(BuyOrderChanged(OrderRetryDue(orderId)));
        });
      case OrderStopTimers(:final orderId):
        _locks.remove(orderId)?.cancel();
        _retries.remove(orderId)?.cancel();
      case OrderRelease(:final orderId):
        if (before case BuyReview(:final order) when order.orderId == orderId) {
          unawaited(calls.release(order));
        }
    }
  }

  void _confirm(
    BuyFlowCalls calls,
    ServerConfirmEffect<BuyConfirmTarget> effect,
  ) {
    switch (effect) {
      case final ConfirmSend<BuyConfirmTarget> send:
        _answer(calls.confirm(send).then(BuyConfirmChanged.new));
      case ConfirmVerify(:final target, :final attempt):
        _answer(
          calls
              .readOrder(target.order.orderId)
              .then(
                (read) => BuyConfirmChanged(
                  ConfirmVerified(attempt, buyConfirmCheck(read)),
                ),
              ),
        );
    }
  }

  void _answer(Future<BuyFlowEvent> answer) {
    unawaited(
      answer.then((event) {
        if (!isClosed) add(event);
      }),
    );
  }

  @override
  Future<void> close() async {
    // Leaving with a quote on screen abandons it; a confirm in flight or a
    // confirmed order keeps its payjoin (BUY-5).
    final calls = _calls;
    if (calls != null) {
      if (state case BuyReview(:final order)) unawaited(calls.release(order));
    }
    for (final timer in [..._locks.values, ..._retries.values]) {
      timer.cancel();
    }
    _watch?.close();
    await _access.cancel();
    return super.close();
  }
}

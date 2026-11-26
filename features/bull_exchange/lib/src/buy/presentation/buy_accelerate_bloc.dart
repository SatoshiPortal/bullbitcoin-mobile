import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/buy/domain/buy_accelerate_flow.dart';
import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:fees/fees.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

/// The size of a typical express payout, for its fee estimate.
const _expressPayoutVsize = 140;

/// The calls of the accelerate flow, bound to one session.
typedef AccelerateFlowCalls = ({
  Future<ExchangeRead<AccelerateQuote>> Function(String orderId) load,
  Future<ConfirmAnswered<AccelerateTarget, BuyOrder>> Function(
    ConfirmSend<AccelerateTarget> effect,
  )
  accelerate,
  Future<ExchangeRead<Order>> Function(String orderId) readOrder,
});

AccelerateFlowCalls accelerateFlowCallsOf(
  Exchange exchange,
  ExchangeSession session,
  Fees fees,
) {
  final orders = exchange.orders(session.environment);
  final bitcoin = BitcoinNetwork.fromName(session.environment.name);
  return (
    load: (orderId) async {
      final BuyOrder order;
      switch (readOfResult(await orders.getOrder(orderId))) {
        case ReadGot(value: final BuyOrder value):
          order = value;
        case ReadGot():
          return const ReadMalformed('not a buy order');
        case ReadMissing():
          return const ReadMissing();
        case ReadUnreachable(:final reason, :final isNetwork):
          return ReadUnreachable(reason, isNetwork: isNetwork);
        case ReadSessionRejected(:final why):
          return ReadSessionRejected(why);
        case ReadMalformed(:final reason):
          return ReadMalformed(reason);
      }
      final FeeOptions estimate;
      switch (await fees.estimate(bitcoin)) {
        case Ok(:final value):
          estimate = value;
        case Err():
          return const ReadUnreachable('network fees', isNetwork: false);
      }
      final double fiatPerBitcoin;
      switch (await exchange.limitOrders.getRate(order.payinCurrency)) {
        case Ok(:final value):
          fiatPerBitcoin = value.indexPrice;
        case Err(:final failure):
          return readOfExchangeFailure<AccelerateQuote>(failure);
      }
      final entries = switch (await exchange.openUnknownWrites()) {
        Ok(:final value) => value,
        Err() => const <UnknownWrite>[],
      };
      return ReadGot(
        AccelerateQuote(
          order,
          AccelerateFee(
            satPerVbyte: estimate.fastest.value.toDouble(),
            sats: estimate
                .toAbsolute(_expressPayoutVsize)
                .fastest
                .value
                .toInt(),
            fiatPerBitcoin: fiatPerBitcoin,
          ),
          entries,
        ),
      );
    },
    accelerate: (effect) => runServerConfirm(
      gate: exchange.writeGate,
      session: session,
      policy: accelerateConfirmPolicy,
      effect: effect,
      confirm: (target) => orders.accelerateBuyOrder(target.orderId),
    ),
    readOrder: (orderId) async => readOfResult(await orders.getOrder(orderId)),
  );
}

/// Shell of [transitionAccelerateFlow]: applies events one at a time, emits
/// the new state and runs its effects, each answer tagged with its attempt.
class AccelerateFlowBloc
    extends Bloc<AccelerateFlowEvent, AccelerateFlowState> {
  AccelerateFlowBloc({
    required AccelerateFlowCalls Function(ExchangeSession session) calls,
    required ExchangeSession? session,
    required String orderId,
    required Stream<ExchangeAccess> accessChanges,
  }) : this._(
         session == null ? null : calls(session),
         accessChanges,
         accelerateFlowStart(session, orderId),
       );

  AccelerateFlowBloc._(
    this._calls,
    Stream<ExchangeAccess> accessChanges,
    AccelerateFlowNext start,
  ) : super(start.state) {
    on<AccelerateFlowEvent>(_onEvent, transformer: sequential());
    _access = accessChanges.listen((access) {
      if (!isClosed) add(AccelerateSessionChanged(access.signedInSession));
    });
    _run(start.effects);
  }

  final AccelerateFlowCalls? _calls;
  late final StreamSubscription<ExchangeAccess> _access;

  void _onEvent(AccelerateFlowEvent event, Emitter<AccelerateFlowState> emit) {
    final next = transitionAccelerateFlow(state, event);
    if (identical(next.state, state)) return;
    emit(next.state);
    _run(next.effects);
  }

  void _run(List<AccelerateFlowEffect> effects) {
    final calls = _calls;
    if (calls == null) return;
    for (final effect in effects) {
      switch (effect) {
        case AccelerateLoad(:final orderId, :final attempt):
          _answer(
            calls.load(orderId).then((r) => AccelerateLoaded(attempt, r)),
          );
        case AccelerateConfirmEffect(
          effect: final ConfirmSend<AccelerateTarget> send,
        ):
          _answer(calls.accelerate(send).then(AccelerateConfirmChanged.new));
        case AccelerateConfirmEffect(
          effect: ConfirmVerify(:final target, :final attempt),
        ):
          _answer(
            calls
                .readOrder(target.orderId)
                .then(
                  (read) => AccelerateConfirmChanged(
                    ConfirmVerified(attempt, accelerateConfirmCheck(read)),
                  ),
                ),
          );
      }
    }
  }

  void _answer(Future<AccelerateFlowEvent> answer) {
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

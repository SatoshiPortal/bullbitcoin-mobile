import 'dart:async';

import 'package:bull_exchange/src/buy/domain/buy_state.dart';
import 'package:bull_exchange/src/buy/domain/buy_event.dart';
import 'package:bull_exchange/src/buy/presentation/buy_flow_bloc.dart';
import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../orders/order_usecase_fakes.dart';
import '../buy_fixtures.dart';
import '../buy_usecase_fakes.dart';

/// The buy use cases as fakes; every call is logged, with the session it
/// got where it takes one.
final class _Calls {
  final log = <String>[];
  final sessions = <ExchangeSession>{};
  Completer<GatedWrite<Result<BuyOrder, ExchangeWriteFailure>>> confirmAnswer =
      Completer();
  Result<Order, ExchangeReadFailure> reread = Ok(buyOrder());

  void _called(ExchangeSession session, String call) {
    sessions.add(session);
    log.add(call);
  }

  BuyFlowBloc bloc({
    required ExchangeSession? session,
    required Stream<ExchangeAccess> accessChanges,
  }) => BuyFlowBloc(
    session: session,
    accessChanges: accessChanges,
    loadContext: FakeLoadBuyContextUsecase((session) async {
      _called(session, 'load');
      return Ok(buyContext);
    }),
    getMarketRate: FakeGetMarketRateUsecase((_, market) async {
      log.add('rate ${market.currency.code}');
      return const Ok(50000.0);
    }),
    getReceiveAddress: FakeGetBuyReceiveAddressUsecase((option) async {
      log.add('receive ${option.walletId}');
      return const Ok(buyLiquidDestination);
    }),
    validateAddress: FakeValidateBuyAddressUsecase((text) async {
      log.add('validate $text');
      return Ok(DestinationAddress(BtcNetwork.bitcoin, text));
    }),
    createOrder: FakeCreateBuyOrderUsecase((session, effect) async {
      _called(session, 'create ${effect.attempt}');
      return OrderCreateAnswered(effect.attempt, GateAdmitted(Ok(buyOrder())));
    }),
    findCreatedOrder: FakeFindCreatedBuyOrderUsecase((
      session,
      request,
      sentAt,
    ) async {
      _called(session, 'find');
      return const Err(ExchangeMissingFailure());
    }),
    refreshOrder: FakeRefreshBuyOrderUsecase((session, orderId) async {
      _called(session, 'refresh $orderId');
      return Ok(buyOrder());
    }),
    confirmOrder: FakeConfirmBuyOrderUsecase((session, effect) async {
      _called(session, 'confirm ${effect.attempt}');
      return ConfirmAnswered(effect.attempt, await confirmAnswer.future);
    }),
    getOrder: FakeGetOrderUsecase((session, orderId) async {
      _called(session, 'read $orderId');
      return reread;
    }),
    getBuyOrder: FakeGetBuyOrderUsecase((session, orderId) async {
      _called(session, 'watch $orderId');
      return Ok(buyOrder(status: OrderStatus.inProgress));
    }),
    releasePayjoin: FakeReleaseBuyPayjoinUsecase(
      (order) async => log.add('release ${order.orderId}'),
    ),
    settlePayout: FakeSettleBuyPayoutUsecase(
      (order, walletId) async => log.add('settled ${order.orderId} $walletId'),
    ),
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Calls calls;
  late StreamController<ExchangeAccess> access;
  late BuyFlowBloc bloc;

  Future<void> run(Future<void> Function() body) =>
      withClock(Clock.fixed(buyBeforeDeadline), () async {
        calls = _Calls();
        access = StreamController<ExchangeAccess>.broadcast();
        bloc = calls.bloc(session: buySession, accessChanges: access.stream);
        try {
          await body();
        } finally {
          await bloc.close();
          await access.close();
        }
      });

  Future<void> send(List<BuyFlowEvent> events) async {
    for (final event in events) {
      bloc.add(event);
      await _settle();
    }
  }

  Future<void> toReview() async {
    await _settle();
    await send(const [
      BuyAmountChanged(AmountTyped('10')),
      BuyContinuePressed(),
    ]);
  }

  test('runs each state effect with the flow session', () async {
    await run(() async {
      await _settle();
      expect(calls.sessions, {buySession});
      expect(calls.log, ['load', 'rate CAD', 'receive w-lq']);
      expect(bloc.state, isA<BuyEntry>());
      await send(const [
        BuyAmountChanged(AmountTyped('10')),
        BuyContinuePressed(),
      ]);
      expect(calls.log.last, 'create 1');
      expect(bloc.state, isA<BuyReview>());
    });
  });

  test('a typed external address is validated by the host', () async {
    await run(() async {
      await _settle();
      await send(const [
        BuyDestinationPicked(null),
        BuyAddressTyped('bc1qexternal'),
      ]);
      expect(calls.log.last, 'validate bc1qexternal');
      expect(
        (bloc.state as BuyEntry).destination,
        isA<PickChosen<DestinationOption, Destination>>(),
      );
    });
  });

  test('Confirm pressed twice sends one confirm; an unknown outcome '
      're-reads the order', () async {
    await run(() async {
      await toReview();
      await send([
        BuyConfirmPressed(buyBeforeDeadline),
        BuyConfirmPressed(buyBeforeDeadline),
        const BuyBackPressed(),
      ]);
      expect(calls.log.where((l) => l.startsWith('confirm')), ['confirm 1']);
      expect(bloc.state, isA<BuyConfirming>());
      calls.reread = Ok(buyOrder(status: OrderStatus.inProgress));
      calls.confirmAnswer.complete(
        const GateAdmitted(Err(ExchangeWriteOutcomeUnknownFailure('lost'))),
      );
      await _settle();
      expect(calls.log, contains('read b-1'));
      expect(bloc.state, isA<BuyDone>());
      expect(calls.log, isNot(contains('release b-1')));
    });
  });

  test('Back from the quote releases its payjoin', () async {
    await run(() async {
      await toReview();
      await send(const [BuyBackPressed()]);
      expect(calls.log.last, 'release b-1');
      expect(bloc.state, isA<BuyEntry>());
    });
  });

  test('closing on the quote releases it; closing while confirming does '
      'not (BUY-5)', () async {
    await run(() async {
      await toReview();
      await bloc.close();
      await _settle();
      expect(calls.log.last, 'release b-1');
    });
    await run(() async {
      await toReview();
      await send([BuyConfirmPressed(buyBeforeDeadline)]);
      await bloc.close();
      await _settle();
      expect(calls.log, isNot(contains('release b-1')));
    });
  });

  test('a payout completed at the confirm labels and syncs once', () async {
    await run(() async {
      await toReview();
      await send([BuyConfirmPressed(buyBeforeDeadline)]);
      calls.confirmAnswer.complete(
        GateAdmitted(
          Ok(
            buyOrder(
              status: OrderStatus.completed,
              payout: OrderPayoutStatus.completed,
            ),
          ),
        ),
      );
      await _settle();
      expect(bloc.state, isA<BuyDone>());
      expect(calls.log.where((l) => l.startsWith('settled')), [
        'settled b-1 w-lq',
      ]);
    });
  });

  test('a session change ends the flow', () async {
    await run(() async {
      await _settle();
      access.add(const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet));
      await _settle();
      expect(bloc.state, isA<BuySessionEnded>());
    });
  });

  test('without a session nothing runs', () async {
    final calls = _Calls();
    final none = calls.bloc(session: null, accessChanges: const Stream.empty());
    addTearDown(none.close);
    await _settle();
    expect(none.state, isA<BuySessionEnded>());
    expect(calls.log, isEmpty);
  });
}

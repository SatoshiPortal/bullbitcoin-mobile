import 'dart:async';

import 'package:bull_exchange/src/buy/domain/buy_flow.dart';
import 'package:bull_exchange/src/buy/presentation/buy_flow_bloc.dart';
import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../buy_fixtures.dart';

final class _Calls {
  final log = <String>[];
  final sessions = <ExchangeSession>[];
  Completer<GatedWrite<ExchangeWrite<BuyOrder>>> confirmAnswer = Completer();
  ExchangeRead<Order> reread = ReadGot(buyOrder());

  BuyFlowCalls of(ExchangeSession session) {
    sessions.add(session);
    return (
      loadContext: () async {
        log.add('load');
        return ReadGot(buyContext);
      },
      rate: (market) async {
        log.add('rate ${market.currency.code}');
        return const ReadGot(50000.0);
      },
      receiveAddress: (option) async {
        log.add('receive ${option.walletId}');
        return const Ok(buyLiquidDestination);
      },
      validateAddress: (text) async {
        log.add('validate $text');
        return Ok(DestinationAddress(BtcNetwork.bitcoin, text));
      },
      create: (effect) async {
        log.add('create ${effect.attempt}');
        return OrderCreateAnswered(
          effect.attempt,
          GateAdmitted(WriteDone(buyOrder())),
        );
      },
      findCreated: (request, sentAt) async {
        log.add('find');
        return const ReadMissing();
      },
      refresh: (orderId) async {
        log.add('refresh $orderId');
        return ReadGot(buyOrder());
      },
      confirm: (effect) async {
        log.add('confirm ${effect.attempt}');
        return ConfirmAnswered(effect.attempt, await confirmAnswer.future);
      },
      readOrder: (orderId) async {
        log.add('read $orderId');
        return reread;
      },
      watchOrder: (orderId) async {
        log.add('watch $orderId');
        return ReadGot(buyOrder(status: OrderStatus.inProgress));
      },
      release: (order) async => log.add('release ${order.orderId}'),
      settled: (order, walletId) async =>
          log.add('settled ${order.orderId} $walletId'),
    );
  }
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
        bloc = BuyFlowBloc(
          calls: calls.of,
          session: buySession,
          accessChanges: access.stream,
        );
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
      expect(calls.sessions, [buySession]);
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
      calls.reread = ReadGot(buyOrder(status: OrderStatus.inProgress));
      calls.confirmAnswer.complete(
        const GateAdmitted(WriteOutcomeUnknown('lost')),
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
          WriteDone(
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
    final none = BuyFlowBloc(
      calls: (_) => throw StateError('no session, no calls'),
      session: null,
      accessChanges: const Stream.empty(),
    );
    addTearDown(none.close);
    await _settle();
    expect(none.state, isA<BuySessionEnded>());
  });
}

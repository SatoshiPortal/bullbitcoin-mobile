import 'dart:async';

import 'package:bull_exchange/src/limit_orders/domain/limit_order_flow.dart';
import 'package:bull_exchange/src/limit_orders/presentation/limit_order_flow_bloc.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../limit_order_fixtures.dart';

final class _Calls {
  final log = <String>[];
  final sessions = <ExchangeSession>[];
  Completer<GatedWrite<ExchangeWrite<LimitOrder>>> createAnswer = Completer();
  ExchangeRead<List<LimitOrder>> recent = const ReadGot([]);

  LimitFlowCalls of(ExchangeSession session) {
    sessions.add(session);
    return (
      loadContext: () async {
        log.add('load');
        return ReadGot(
          LimitOrderContext(
            userSummary(),
            limitDefaultWallets(),
            const [],
            const [],
          ),
        );
      },
      rate: (market) async {
        log.add('rate ${market.currency.code}');
        return ReadGot(limitOrderRate());
      },
      receiveAddress: (option) async {
        log.add('receive ${option.walletId}');
        return Ok(
          DestinationAppWallet(option.walletId, option.rail, 'bc1qapp'),
        );
      },
      lightningAddress: (text) async {
        log.add('lightning $text');
        return Ok(DestinationAddress(BtcNetwork.lightning, text));
      },
      create: (effect) async {
        log.add('create ${effect.attempt}');
        return ConfirmAnswered(effect.attempt, await createAnswer.future);
      },
      recentOrders: () async {
        log.add('recent');
        return recent;
      },
    );
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _Calls calls;
  late StreamController<ExchangeAccess> access;
  late LimitFlowBloc bloc;

  setUp(() {
    calls = _Calls();
    access = StreamController<ExchangeAccess>.broadcast();
    bloc = LimitFlowBloc(
      calls: calls.of,
      session: limitSession,
      accessChanges: access.stream,
    );
  });

  tearDown(() async {
    await bloc.close();
    await access.close();
  });

  Future<void> send(List<LimitFlowEvent> events) async {
    for (final event in events) {
      bloc.add(event);
      await _settle();
      await _settle();
    }
  }

  Future<void> toReview() => send(const [
    LimitContinuePressed(),
    LimitPriceTyped(80000),
    LimitContinuePressed(),
    LimitDestinationChanged(
      PickChose(
        DestinationOptionDefaultWallet(BtcNetwork.bitcoin, limitBitcoinAddress),
      ),
    ),
    LimitContinuePressed(),
    LimitAmountChanged(AmountTyped('200')),
    LimitContinuePressed(),
  ]);

  test('runs each state effect with the flow session', () async {
    await _settle();
    await _settle();
    expect(calls.sessions, [limitSession]);
    expect(bloc.state, isA<LimitIntro>());
    await toReview();
    expect(calls.log, ['load', 'rate CAD', 'rate CAD']);
    expect(
      bloc.state,
      isA<LimitReview>().having((s) => s.check, 'check', isA<ReviewLive>()),
    );
  });

  test('Confirm pressed twice sends one create; an unknown outcome '
      're-reads the recent orders', () async {
    await _settle();
    await toReview();
    await send(const [LimitConfirmPressed(), LimitConfirmPressed()]);
    expect(calls.log.where((l) => l.startsWith('create')), ['create 1']);
    final request = (bloc.state as LimitCreating).request;
    calls.recent = ReadGot([
      LimitOrder(
        id: 'lo-7',
        number: 'LO-7',
        fiatAmount: 200,
        currencyCode: 'CAD',
        limitPrice: request.target.limitPrice,
        estimatedBtcAmount: 0.002,
        status: LimitOrderStatus.active,
        createdAt: DateTime.utc(2026, 11, 24),
        expiresAt: DateTime.utc(2026, 12, 24),
        address: limitBitcoinAddress,
      ),
    ]);
    calls.createAnswer.complete(
      const GateAdmitted(WriteOutcomeUnknown('lost')),
    );
    await _settle();
    await _settle();
    await _settle();
    expect(calls.log.last, 'recent');
    expect(
      bloc.state,
      isA<LimitDone>().having((s) => s.order.id, 'order', 'lo-7'),
    );
  });

  test('an app wallet reads its receive address', () async {
    await _settle();
    await send(const [LimitContinuePressed()]);
    bloc.add(
      const LimitDestinationChanged(
        PickChose(DestinationOptionAppWallet('w-1', BtcNetwork.bitcoin)),
      ),
    );
    await _settle();
    // Not offered by the loaded context: the pick ignores it.
    expect(calls.log, isNot(contains('receive w-1')));
  });

  test('a session change ends the flow', () async {
    await _settle();
    access.add(const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet));
    await _settle();
    expect(bloc.state, isA<LimitSessionEnded>());
  });

  test('without a session nothing runs', () async {
    final before = [...calls.sessions];
    final none = LimitFlowBloc(
      calls: calls.of,
      session: null,
      accessChanges: const Stream.empty(),
    );
    addTearDown(none.close);
    await _settle();
    expect(none.state, isA<LimitSessionEnded>());
    expect(calls.sessions, before);
  });

  group('lightningAddressOf', () {
    test('an empty text is no address', () async {
      expect(await lightningAddressOf('  '), isNull);
    });

    test(
      'a parser failure is no address; a programmer error is thrown',
      () async {
        expect(
          await lightningAddressOf('x', parse: (_) async => throw Exception()),
          isNull,
        );
        await expectLater(
          lightningAddressOf('x', parse: (_) async => throw StateError('bug')),
          throwsStateError,
        );
      },
    );
  });
}

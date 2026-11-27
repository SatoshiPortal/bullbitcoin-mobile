import 'dart:async';

import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;

const _session = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 's',
);

final _order = Order.sell(
  orderId: 'o-1',
  orderType: OrderType.sell,
  message: OrderMessage(code: '', message: ''),
  orderNumber: 1,
  payinAmount: 0.001,
  payinCurrency: 'BTC',
  payoutAmount: 100,
  payoutCurrency: 'CAD',
  payinMethod: OrderPaymentMethod.bitcoin,
  payoutMethod: OrderPaymentMethod.cadBalance,
  orderStatus: OrderStatus.inProgress,
  payinStatus: OrderPayinStatus.awaitingPayment,
  payoutStatus: OrderPayoutStatus.notStarted,
  confirmationDeadline: DateTime.now().add(const Duration(hours: 1)),
  createdAt: DateTime.utc(2026, 11, 24),
  bitcoinAddress: 'tb1q',
  isTestnet: true,
) as SellOrder;

const _target = OnchainDeposit('tb1q');
const _spend = PayinWalletSpend(
  'w1',
  PayinSpendOptions(
    fee: PayinFeeRate(250),
    replaceByFee: true,
    coins: {},
    payjoin: false,
  ),
);
const _built = PayinBuilt<PayinSpend>(
  _spend,
  'tx1',
  SignedBitcoinPayin<String>('signed'),
);

void main() {
  late List<String> calls;
  late List<PayinEvent<PayinSpend>> events;
  late StreamController<PayjoinProgress> payjoin;
  late PayinRunner runner;

  setUp(() {
    calls = [];
    events = [];
    payjoin = StreamController<PayjoinProgress>();
    runner = PayinRunner(
      (
        build: (effect) async {
          calls.add('build ${effect.walletId}');
          return const PayinBuildOk(_built);
        },
        send: (built) async {
          calls.add('send ${built.txid}');
          return const PayinBroadcastOutcomeUnknown('tx1');
        },
        readOrder: (orderId) async {
          calls.add('read $orderId');
          return ReadGot(_order);
        },
        txSeen: (txid) async {
          calls.add('seen $txid');
          return null;
        },
        watchPayjoin: (sessionId) {
          calls.add('payjoin $sessionId');
          return payjoin.stream;
        },
        retryPayjoin: (sessionId) async => calls.add('retry $sessionId'),
        journalUnknown: (orderId, network, txid) async =>
            calls.add('journal $orderId $txid'),
      ),
      ExchangeWriteGate(),
      _session,
      events.add,
    );
  });

  test('build, send through the gate and journal an unknown send', () {
    fakeAsync((async) {
      runner.run([
        PayinBuild<PayinSpend>(_order, _target, _spend, 1),
        PayinSend<PayinSpend>(_order, _target, 2, _built),
      ]);
      async.flushMicrotasks();
      expect(calls, ['build w1', 'send tx1', 'journal o-1 tx1']);
      expect(events, [
        isA<PayinBuildAnswered<PayinSpend>>().having(
          (e) => e.attempt,
          'attempt',
          1,
        ),
        isA<PayinSendAnswered<PayinSpend>>().having(
          (e) => e.attempt,
          'attempt',
          2,
        ),
      ]);
    });
  });

  test('a look-up reads the order and the transaction together', () {
    fakeAsync((async) {
      runner.run([PayinVerify<PayinSpend>(_order, _target, 3, 'tx1')]);
      async.flushMicrotasks();
      expect(calls, ['seen tx1', 'read o-1']);
      expect(
        events.single,
        isA<PayinVerified<PayinSpend>>().having((e) => e.attempt, 'attempt', 3),
      );
    });
  });

  test('a payjoin watch that ends is an event, and Stop cancels it', () {
    fakeAsync((async) {
      runner.run(const [PayinFollowPayjoin<PayinSpend>('pj')]);
      payjoin.add(const PayjoinNegotiating());
      async.flushMicrotasks();
      unawaited(payjoin.close());
      async.flushMicrotasks();
      expect(events, [
        isA<PayinPayjoinUpdated<PayinSpend>>(),
        isA<PayinPayjoinWatchEnded<PayinSpend>>(),
      ]);
    });
  });

  test('the order watch polls on its timer and stops', () {
    fakeAsync((async) {
      runner.run(const [
        PayinWatchEffect<PayinSpend>(WatchSchedulePoll('o-1', 1)),
      ]);
      async.elapse(const Duration(seconds: 5));
      expect(calls, ['read o-1']);
      expect(
        (events.single as PayinWatchEvent<PayinSpend>).event,
        isA<WatchPolled<Order>>().having((e) => e.ticket, 'ticket', 1),
      );
      runner.run(const [
        PayinWatchEffect<PayinSpend>(WatchSchedulePoll('o-1', 2)),
        PayinWatchEffect<PayinSpend>(WatchStop('o-1')),
      ]);
      async.elapse(const Duration(minutes: 1));
      expect(calls, ['read o-1']);
    });
  });

  test('nothing answers after close', () {
    fakeAsync((async) {
      runner.run([PayinRecheck<PayinSpend>('o-1', 1)]);
      runner.close();
      async.flushMicrotasks();
      expect(events, isEmpty);
    });
  });

  test(
    'a handoff that already started remains journaled after revocation',
    () async {
      final attempt = PayinWalletAttempt(
        const PayinWalletWitness(
          walletId: 'w1',
          network: BitcoinNetwork.testnet,
          generation: 1,
          currentReceipt: _liveReceipt,
        ),
      );
      final effect = PayinSend<PayinSpend>(
        _order,
        _target,
        1,
        PayinBuilt(
          PayinWalletSpend('w1', _spend.options, walletAttempt: attempt),
          'tx1',
          _built.payload,
        ),
      );
      final entered = Completer<void>();
      final submitted = Completer<PayinBroadcastOutcome>();
      final gate = ExchangeWriteGate();
      Future<PayinSendAnswered<PayinSpend>> send() => runPayinSend(
        gate: gate,
        session: _session,
        effect: effect,
        now: DateTime.now,
        send: (_) {
          entered.complete();
          return submitted.future;
        },
        journalUnknown: (order, _, txid) async => calls.add('$order $txid'),
      );
      final first = send();
      await entered.future;
      attempt.retire();
      submitted.complete(const PayinHandedToPayjoin('pj', 'tx1'));
      expect(
        (await first).answer,
        isA<GateAdmitted<PayinBroadcastOutcome>>().having(
          (value) => value.result,
          'outcome',
          const PayinHandedToPayjoin('pj', 'tx1'),
        ),
      );
      expect(
        (await send()).answer,
        isA<GateAdmitted<PayinBroadcastOutcome>>().having(
          (value) => value.result,
          'outcome',
          isA<PayinBroadcastNotSent>(),
        ),
      );
      expect(calls, ['o-1 tx1']);
    },
  );
}

Object _liveReceipt() => true;

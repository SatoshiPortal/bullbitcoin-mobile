import 'dart:async';

import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../orders/order_usecase_fakes.dart';
import 'payin_fixtures.dart';
import 'payin_usecase_fakes.dart';

import 'package:primitives/primitives.dart';

void main() {
  late List<String> calls;
  late List<PayinEvent<PayinSpend>> events;
  late StreamController<PayjoinProgress> payjoin;
  late SellOrder order;
  late PayinRunner runner;

  setUp(() {
    calls = [];
    events = [];
    payjoin = StreamController<PayjoinProgress>();
    order = payinOrder();
    runner = PayinRunner(
      fakePayin(
        build: FakeBuildPayinUsecase((effect) async {
          calls.add('build ${effect.walletId}');
          return const PayinBuildOk(payinBuilt);
        }),
        send: FakeSendPayinUsecase((session, effect) async {
          calls.add('send ${effect.built.txid} ${session.sessionId}');
          return PayinSendAnswered(
            effect.attempt,
            const GateAdmitted(PayinBroadcastOutcomeUnknown('tx1')),
          );
        }),
        getOrder: FakeGetOrderUsecase((session, orderId) async {
          calls.add('read $orderId ${session.sessionId}');
          return Ok(order);
        }),
        transactionSeen: FakeCheckTransactionSeenUsecase((txid) async {
          calls.add('seen $txid');
          return null;
        }),
        watchPayjoin: FakeWatchPayjoinUsecase((sessionId) {
          calls.add('payjoin $sessionId');
          return payjoin.stream;
        }),
        retryPayjoin: FakeRetryPayjoinProposalUsecase(
          (sessionId) async => calls.add('retry $sessionId'),
        ),
      ),
      payinSession,
      events.add,
    );
  });

  test('build, then send with the flow session', () {
    fakeAsync((async) {
      runner.run([
        PayinBuild<PayinSpend>(order, payinTarget, payinWalletSpend, 1),
        PayinSend<PayinSpend>(order, payinTarget, 2, payinBuilt),
      ]);
      async.flushMicrotasks();
      expect(calls, ['build w1', 'send tx1 s']);
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
      runner.run([PayinVerify<PayinSpend>(order, payinTarget, 3, 'tx1')]);
      async.flushMicrotasks();
      expect(calls, ['seen tx1', 'read o-1 s']);
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
      expect(calls, ['payjoin pj']);
      expect(events, [
        isA<PayinPayjoinUpdated<PayinSpend>>(),
        isA<PayinPayjoinWatchEnded<PayinSpend>>(),
      ]);
    });
  });

  test('a payjoin retry asks the session again', () {
    fakeAsync((async) {
      runner.run(const [PayinRetryPayjoin<PayinSpend>('pj')]);
      async.flushMicrotasks();
      expect(calls, ['retry pj']);
      expect(events, isEmpty);
    });
  });

  test('the order watch polls on its timer and stops', () {
    fakeAsync((async) {
      runner.run(const [
        PayinWatchEffect<PayinSpend>(WatchSchedulePoll('o-1', 1)),
      ]);
      async.elapse(const Duration(seconds: 5));
      expect(calls, ['read o-1 s']);
      expect(
        (events.single as PayinWatchEvent<PayinSpend>).event,
        isA<WatchPolled<Order>>().having((e) => e.ticket, 'ticket', 1),
      );
      runner.run(const [
        PayinWatchEffect<PayinSpend>(WatchSchedulePoll('o-1', 2)),
        PayinWatchEffect<PayinSpend>(WatchStop('o-1')),
      ]);
      async.elapse(const Duration(minutes: 1));
      expect(calls, ['read o-1 s']);
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
}

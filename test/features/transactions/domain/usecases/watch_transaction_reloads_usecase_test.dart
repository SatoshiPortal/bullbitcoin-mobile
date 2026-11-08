import 'dart:async';
import 'package:fake_async/fake_async.dart';

import 'package:bb_mobile/features/transactions/domain/usecases/watch_transaction_reloads_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;

void main() {
  late StreamController<void> finishes;
  late StreamController<bool> activity;
  late StreamController<WalletRevisionState> revisions;
  late StreamSubscription<TransactionHistoryUpdate> subscription;
  late WatchTransactionReloadsUsecase watcher;
  var active = false;
  var reloads = 0;

  void revision(
    String id, {
    WalletLifecycle lifecycle = WalletLifecycle.active,
    int generation = 0,
  }) {
    revisions.add(
      WalletRevisionState(
        stamp: WalletRevision(
          key: WalletKey(id: id, network: BitcoinNetwork.mainnet),
          generation: generation,
          revision: 1,
        ),
        lifecycle: lifecycle,
      ),
    );
  }

  void setActive(bool value) {
    active = value;
    activity.add(value);
  }

  void setup() {
    finishes = StreamController<void>.broadcast();
    activity = StreamController<bool>.broadcast(sync: true);
    revisions = StreamController<WalletRevisionState>.broadcast();
    active = false;
    reloads = 0;
    watcher = WatchTransactionReloadsUsecase(
      WalletFacade(
        revisions.stream,
        syncFinished: finishes.stream,
        syncPassActivity: activity.stream,
        isSyncPassActive: () => active,
      ),
    );
    subscription = watcher.execute().listen((update) {
      if (update == TransactionHistoryUpdate.reload) reloads++;
    });
  }

  void check(void Function(FakeAsync) body) {
    fakeAsync((clock) {
      setup();
      try {
        body(clock);
      } finally {
        subscription.cancel();
        clock.flushMicrotasks();
        activity.close();
        revisions.close();
        finishes.close();
        clock.flushMicrotasks();
      }
    });
  }

  test(
    'a pass cancels a pending direct revision reload',
    () => check((clock) {
      revision('a');
      clock.flushMicrotasks();
      setActive(true);
      revision('b');
      clock.elapse(const Duration(seconds: 10));
      clock.flushMicrotasks();
      expect(reloads, 0);
      setActive(false);
      clock.elapse(Duration.zero);
      expect(reloads, 1);
      clock.elapse(const Duration(seconds: 10));
      clock.flushMicrotasks();
      expect(reloads, 1);
    }),
  );

  test(
    'subscribing mid-pass waits for its completion',
    () => check((clock) {
      subscription.cancel();
      clock.flushMicrotasks();
      setActive(true);
      subscription = watcher.execute().listen((update) {
        if (update == TransactionHistoryUpdate.reload) reloads++;
      });
      revision('a');
      clock.elapse(const Duration(seconds: 10));
      clock.flushMicrotasks();
      expect(reloads, 0);
      setActive(false);
      clock.elapse(Duration.zero);
      expect(reloads, 1);
    }),
  );

  test(
    'direct and background deliveries coalesce outside a pass',
    () => check((clock) {
      revision('a');
      finishes.add(null);
      revision('b');
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 3));
      clock.flushMicrotasks();
      expect(reloads, 1);
      revision('a', generation: 1);
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 3));
      clock.flushMicrotasks();
      expect(reloads, 2);
    }),
  );

  test(
    'a new pass cancels a queued completion but later direct finishes reload',
    () => check((clock) {
      setActive(true);
      setActive(false);
      setActive(true);
      clock.elapse(Duration.zero);
      expect(reloads, 0);
      setActive(false);
      clock.elapse(Duration.zero);
      expect(reloads, 1);
      finishes.add(null);
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 3));
      expect(reloads, 2);
    }),
  );

  test(
    'creation and deletion invalidate the global joins',
    () => check((clock) {
      revision('created', generation: 1);
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 3));
      clock.flushMicrotasks();
      expect(reloads, 1);
      revision('created', lifecycle: WalletLifecycle.deleted, generation: 1);
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 3));
      clock.flushMicrotasks();
      expect(reloads, 2);
    }),
  );

  test(
    'closing cancels pending timers and subscriptions',
    () => check((clock) {
      revision('a');
      clock.flushMicrotasks();
      subscription.cancel();
      clock.flushMicrotasks();
      setActive(true);
      setActive(false);
      clock.elapse(const Duration(seconds: 10));
      clock.flushMicrotasks();
      expect(reloads, 0);
      expect(activity.hasListener, isFalse);
      expect(revisions.hasListener, isFalse);
      expect(finishes.hasListener, isFalse);
    }),
  );
}

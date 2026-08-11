import 'dart:async';

import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/sync/sync_kind.dart';
import 'package:bb_mobile/features/swap/order_swap_watcher.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSyncCoordinator extends Mock implements SyncCoordinator {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deduplicates overlapping refresh requests', () async {
    final coordinator = _MockSyncCoordinator();
    final completion = Completer<void>();
    when(
      () => coordinator.sync(only: {SyncKind.swaps}),
    ).thenAnswer((_) => completion.future);
    final watcher = OrderSwapWatcher(coordinator);

    final first = watcher.refresh();
    final second = watcher.refresh();
    await Future<void>.delayed(Duration.zero);

    verify(() => coordinator.sync(only: {SyncKind.swaps})).called(1);
    completion.complete();
    await Future.wait([first, second]);
    watcher.dispose();
  });

  test('honors the retry-after delay after rate limiting', () {
    final coordinator = _MockSyncCoordinator();
    var calls = 0;
    when(() => coordinator.sync(only: {SyncKind.swaps}))
        .thenAnswer((_) async {
          calls++;
        });
    when(() => coordinator.lastSwapSyncOutcome).thenReturn(
      const SyncOutcome.rateLimited(retryAfter: Duration(minutes: 2)),
    );
    final watcher = OrderSwapWatcher(coordinator);

    fakeAsync((async) {
      watcher.start();
      async.elapse(Duration.zero);
      async.flushMicrotasks();
      expect(calls, 1);
      async.elapse(const Duration(minutes: 1, seconds: 59));
      async.flushMicrotasks();
      expect(calls, 1);
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(calls, 2);
      watcher.dispose();
    });
  });

  test('backs off when there are no pending orders', () {
    final coordinator = _MockSyncCoordinator();
    var calls = 0;
    when(() => coordinator.sync(only: {SyncKind.swaps}))
        .thenAnswer((_) async {
          calls++;
        });
    when(() => coordinator.lastSwapSyncOutcome).thenReturn(
      const SyncOutcome.idle(),
    );
    final watcher = OrderSwapWatcher(coordinator);

    fakeAsync((async) {
      watcher.start();
      async.elapse(Duration.zero);
      async.flushMicrotasks();
      expect(calls, 1);
      async.elapse(const Duration(minutes: 4, seconds: 59));
      async.flushMicrotasks();
      expect(calls, 1);
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(calls, 2);
      watcher.dispose();
    });
  });
}

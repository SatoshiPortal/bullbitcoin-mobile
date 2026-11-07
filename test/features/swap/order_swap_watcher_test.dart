import 'dart:async';

import 'package:bb_mobile/features/swap/domain/entities/order_swap_polling.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/swap/domain/usecases/schedule_order_swap_refresh_usecase.dart';
import 'package:bb_mobile/features/swap/order_swap_watcher.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockScheduleRefresh extends Mock
    implements ScheduleOrderSwapRefreshUsecase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deduplicates overlapping refresh requests', () async {
    final coordinator = _MockScheduleRefresh();
    final completion = Completer<OrderSwapPollingAttempt>();
    when(() => coordinator.execute()).thenAnswer((_) => completion.future);
    final watcher = OrderSwapWatcher(coordinator);

    final first = watcher.refresh();
    final second = watcher.refresh();
    await Future<void>.delayed(Duration.zero);

    verify(() => coordinator.execute()).called(1);
    completion.complete(const OrderSwapPollingAttempt());
    await Future.wait([first, second]);
    watcher.dispose();
  });

  test('honors the retry-after delay after rate limiting', () {
    final coordinator = _MockScheduleRefresh();
    var calls = 0;
    when(() => coordinator.execute()).thenAnswer((_) async {
      calls++;
      return const OrderSwapPollingAttempt(
        lastOutcome: OrderSwapPolling.rateLimited(
          retryAfter: Duration(minutes: 2),
        ),
      );
    });
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
    final coordinator = _MockScheduleRefresh();
    var calls = 0;
    when(() => coordinator.execute()).thenAnswer((_) async {
      calls++;
      return const OrderSwapPollingAttempt(
        lastOutcome: OrderSwapPolling.idle(),
      );
    });
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

  test('stops polling after the provider requires an app update', () {
    final coordinator = _MockScheduleRefresh();
    var calls = 0;
    var updateRequired = false;
    when(() => coordinator.execute()).thenAnswer((_) async {
      calls++;
      updateRequired = true;
      return const OrderSwapPollingAttempt(
        lastOutcome: OrderSwapPolling.active(),
      );
    });
    final watcher = OrderSwapWatcher(
      coordinator,
      isAppUpdateRequired: () => updateRequired,
    );

    fakeAsync((async) {
      watcher.start();
      async.elapse(Duration.zero);
      async.flushMicrotasks();
      expect(calls, 1);
      async.elapse(const Duration(minutes: 10));
      async.flushMicrotasks();
      expect(calls, 1);
      watcher.dispose();
    });
  });
  for (final (outcome, delay) in <(OrderSwapPolling?, Duration)>[
    (null, const Duration(seconds: 30)),
    (const OrderSwapPolling.active(), const Duration(seconds: 30)),
    (const OrderSwapPolling.rateLimited(), const Duration(seconds: 60)),
    (
      const OrderSwapPolling.rateLimited(retryAfter: Duration(seconds: 10)),
      const Duration(seconds: 60),
    ),
  ]) {
    test(
      'failed attempt retains polling delay $delay for ${outcome?.kind}',
      () {
        final schedule = _MockScheduleRefresh();
        var calls = 0;
        when(schedule.execute).thenAnswer((_) async {
          calls++;
          return OrderSwapPollingAttempt(
            lastOutcome: outcome,
            failure: const SwapUnexpectedFailure('refresh failed'),
          );
        });
        final watcher = OrderSwapWatcher(schedule);
        fakeAsync((async) {
          watcher.start();
          async.elapse(Duration.zero);
          async.flushMicrotasks();
          expect(calls, 1);
          async.elapse(delay - const Duration(milliseconds: 1));
          expect(calls, 1);
          async.elapse(const Duration(milliseconds: 1));
          async.flushMicrotasks();
          expect(calls, 2);
          watcher.dispose();
        });
      },
    );
  }
}

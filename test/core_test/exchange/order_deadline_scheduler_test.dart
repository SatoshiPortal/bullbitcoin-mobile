import 'package:bb_mobile/core/exchange/domain/order_deadline_scheduler.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const retryDelay = Duration(seconds: 5);
  const maxRetries = 3;

  late int dueCount;
  late int giveUpCount;
  late OrderDeadlineScheduler scheduler;

  setUp(() {
    dueCount = 0;
    giveUpCount = 0;
    scheduler = OrderDeadlineScheduler(
      onDue: () => dueCount++,
      onGiveUp: () => giveUpCount++,
      retryDelay: retryDelay,
      maxRetries: maxRetries,
    );
  });

  tearDown(() => scheduler.dispose());

  test('a lock still ahead fires at its exact instant, not a second early', () {
    fakeAsync((time) {
      scheduler.track(clock.now().add(const Duration(seconds: 90)));

      time.elapse(const Duration(seconds: 89, milliseconds: 999));
      expect(dueCount, 0);
      expect(scheduler.isPending, isTrue);

      time.elapse(const Duration(milliseconds: 1));
      expect(dueCount, 1);
      expect(scheduler.isPending, isFalse);
    });
  });

  test('a lapsed quote retries after the delay, never at once', () {
    fakeAsync((time) {
      scheduler.track(clock.now().subtract(const Duration(minutes: 1)));
      expect(dueCount, 0);

      time.elapse(retryDelay - const Duration(milliseconds: 1));
      expect(dueCount, 0);

      time.elapse(const Duration(milliseconds: 1));
      expect(dueCount, 1);
    });
  });

  test('a quote lapsing right now counts as lapsed', () {
    fakeAsync((time) {
      scheduler.track(clock.now());
      expect(dueCount, 0);
      time.elapse(retryDelay);
      expect(dueCount, 1);
    });
  });

  test('a failed refresh retries after the delay', () {
    fakeAsync((time) {
      scheduler.refreshFailed();
      time.elapse(retryDelay);
      expect(dueCount, 1);
    });
  });

  test('exhausted retries give up once and go quiet', () {
    fakeAsync((time) {
      final lapsed = clock.now().subtract(const Duration(minutes: 1));
      scheduler.track(lapsed);
      for (var i = 0; i < maxRetries; i++) {
        time.elapse(retryDelay);
        expect(dueCount, i + 1);
        scheduler.track(lapsed);
      }
      expect(giveUpCount, 1);
      expect(scheduler.isPending, isFalse);

      time.elapse(retryDelay * 10);
      expect(dueCount, maxRetries);
      expect(giveUpCount, 1);
    });
  });

  test('a fresh lock cancels the pending retry and resets the budget', () {
    fakeAsync((time) {
      final lapsed = clock.now().subtract(const Duration(minutes: 1));
      scheduler.track(lapsed);
      time.elapse(retryDelay);
      scheduler.track(lapsed);
      expect(dueCount, 1);

      scheduler.track(clock.now().add(const Duration(seconds: 30)));
      time.elapse(retryDelay);
      expect(dueCount, 1, reason: 'the retry was replaced by the new lock');

      time.elapse(const Duration(seconds: 25));
      expect(dueCount, 2);

      // The budget starts over for the new lock.
      for (var i = 0; i < maxRetries; i++) {
        scheduler.track(lapsed);
        time.elapse(retryDelay);
      }
      expect(giveUpCount, 0);
      scheduler.track(lapsed);
      expect(giveUpCount, 1);
    });
  });

  test('no deadline means nothing to watch', () {
    fakeAsync((time) {
      scheduler.track(null);
      expect(scheduler.isPending, isFalse);
      time.elapse(const Duration(minutes: 10));
      expect(dueCount, 0);
    });
  });

  test('cancel stops everything and forgets the retries', () {
    fakeAsync((time) {
      final lapsed = clock.now().subtract(const Duration(minutes: 1));
      scheduler.track(lapsed);
      scheduler.cancel();
      expect(scheduler.isPending, isFalse);
      time.elapse(retryDelay * 2);
      expect(dueCount, 0);

      for (var i = 0; i < maxRetries; i++) {
        scheduler.track(lapsed);
        time.elapse(retryDelay);
      }
      expect(dueCount, maxRetries);
      expect(giveUpCount, 0, reason: 'cancel reset the budget earlier');
    });
  });

  test('never two timers at once', () {
    fakeAsync((time) {
      final lapsed = clock.now().subtract(const Duration(minutes: 1));
      scheduler.track(lapsed);
      scheduler.refreshFailed();
      scheduler.track(lapsed);
      time.elapse(retryDelay);
      expect(dueCount, 1);
    });
  });
}

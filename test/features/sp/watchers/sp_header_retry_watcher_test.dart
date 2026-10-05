import 'dart:async';

import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/resync_sp_listener_usecase.dart';
import 'package:bb_mobile/features/sp/watchers/sp_header_retry_watcher.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

/// Counts restarts and, with [gate] set, holds the callback inside its await
/// so a reset can land mid-flight.
class _FakeResyncSpListenerUsecase implements ResyncSpListenerUsecase {
  int calls = 0;
  Result<void, SpFailure> result = const Ok(null);
  Completer<Result<void, SpFailure>>? gate;

  @override
  Future<Result<void, SpFailure>> execute() async {
    calls++;
    final gate = this.gate;
    if (gate != null) return gate.future;
    return result;
  }
}

void main() {
  const backoff = SpHeaderRetryWatcher.backoff;
  const maxRetries = SpHeaderRetryWatcher.maxRetries;

  late _FakeResyncSpListenerUsecase resync;
  late SpHeaderRetryWatcher watcher;
  late int gaveUp;

  setUp(() {
    resync = _FakeResyncSpListenerUsecase();
    watcher = SpHeaderRetryWatcher(resyncSpListenerUsecase: resync);
    gaveUp = 0;
  });

  void start() => watcher.start(onGaveUp: () => gaveUp++);

  test('a retry fires after the backoff and restarts the listener', () {
    fakeAsync((async) {
      start();

      async.elapse(backoff - const Duration(milliseconds: 1));
      expect(resync.calls, 0);

      async.elapse(const Duration(milliseconds: 1));
      expect(resync.calls, 1);
      expect(watcher.attempts, 1);

      watcher.reset();
    });
  });

  test('a failed restart keeps retrying', () {
    fakeAsync((async) {
      resync.result = const Err(SpUnexpected('electrum down'));
      start();

      async.elapse(backoff * 3);

      expect(resync.calls, 3);
      expect(watcher.attempts, 3);

      watcher.reset();
    });
  });

  test('onGaveUp fires once after the attempts run out', () {
    fakeAsync((async) {
      start();

      async.elapse(backoff * (maxRetries + 1));

      expect(resync.calls, maxRetries);
      expect(gaveUp, 1);
      expect(watcher.attempts, 0);

      // Giving up stops the watcher, so no later tick fires it again.
      async.elapse(backoff * 10);
      expect(gaveUp, 1);
      expect(resync.calls, maxRetries);
    });
  });

  test('a reset during the in-flight restart stops every further retry', () {
    fakeAsync((async) {
      final gate = Completer<Result<void, SpFailure>>();
      resync.gate = gate;
      start();

      // The callback is now parked on the await inside the restart.
      async.elapse(backoff);
      expect(resync.calls, 1);

      // Started publishes Started, which resets the watcher while the restart
      // is still in flight; the stale callback must not re-arm.
      watcher.reset();
      gate.complete(const Ok(null));
      async.flushMicrotasks();

      async.elapse(backoff * 10);
      expect(resync.calls, 1);
      expect(watcher.attempts, 0);
    });
  });

  test('reset zeroes the attempts and a later start retries again', () {
    fakeAsync((async) {
      start();
      async.elapse(backoff);
      expect(watcher.attempts, 1);

      watcher.reset();
      expect(watcher.attempts, 0);

      start();
      async.elapse(backoff);
      expect(resync.calls, 2);
      expect(watcher.attempts, 1);

      watcher.reset();
    });
  });
}

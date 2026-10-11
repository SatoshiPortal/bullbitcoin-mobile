import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_operation_queue.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a stalled operation returns a failure within one minute', () {
    fakeAsync((time) {
      final queue = WalletBackupOperationQueue();
      final pending = Completer<Result<void, WalletBackupFailure>>();
      Result<void, WalletBackupFailure>? result;
      unawaited(
        queue.run(() => pending.future).then((value) => result = value),
      );
      time.elapse(const Duration(minutes: 1));
      expect(result, isA<Err<void, WalletBackupFailure>>());
      pending.complete(const Ok(null));
      time.flushMicrotasks();
      expect(result, isA<Err<void, WalletBackupFailure>>());
    });
  });

  test('expired waiting mutations never execute after the queue recovers', () {
    fakeAsync((time) {
      final queue = WalletBackupOperationQueue();
      final pending = Completer<Result<void, WalletBackupFailure>>();
      unawaited(queue.run(() => pending.future));
      var applied = false;
      Result<void, WalletBackupFailure>? expired;
      unawaited(
        queue
            .run(() async {
              applied = true;
              return const Ok<void, WalletBackupFailure>(null);
            })
            .then((value) => expired = value),
      );
      time.elapse(const Duration(minutes: 1));
      expect(expired, isA<Err<void, WalletBackupFailure>>());
      pending.complete(const Ok(null));
      time.flushMicrotasks();
      expect(applied, isFalse);
      Result<void, WalletBackupFailure>? fresh;
      unawaited(
        queue
            .run(() async => const Ok<void, WalletBackupFailure>(null))
            .then((value) => fresh = value),
      );
      time.flushMicrotasks();
      expect(fresh, isA<Ok<void, WalletBackupFailure>>());
    });
  });

  test('a deadline never permits overlapping mutations', () {
    fakeAsync((time) {
      final queue = WalletBackupOperationQueue();
      final pending = Completer<Result<void, WalletBackupFailure>>();
      Result<void, WalletBackupFailure>? timedOut;
      unawaited(
        queue.run(() => pending.future).then((value) => timedOut = value),
      );
      time.elapse(const Duration(minutes: 1));
      expect(timedOut, isA<Err<void, WalletBackupFailure>>());
      var followingRan = false;
      unawaited(
        queue
            .run(() async {
              followingRan = true;
              return const Ok<void, WalletBackupFailure>(null);
            })
            .then((_) {}),
      );
      time.flushMicrotasks();
      expect(followingRan, isFalse);
      pending.complete(const Ok(null));
      time.flushMicrotasks();
      expect(followingRan, isTrue);
    });
  });
}

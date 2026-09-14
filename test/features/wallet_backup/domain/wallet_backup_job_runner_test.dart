import 'dart:async';

import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_job_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

/// The runner is the only thing serializing Bull backup's remote work, so
/// these tests state its guarantees directly rather than through the feature.
void main() {
  test('one job owns the runner at a time', () async {
    var running = 0;
    var overlapped = false;
    final runner = WalletBackupJobRunner(publish: () async => const Ok(null));

    Future<Result<void, WalletBackupFailure>> job() => runner.run(() async {
      running++;
      if (running > 1) overlapped = true;
      await pumpEventQueue();
      running--;
      return const Ok(null);
    });

    await Future.wait([job(), job(), job()]);

    expect(overlapped, isFalse);
  });

  test('a job queued behind another waits for it to finish', () async {
    final order = <String>[];
    final release = Completer<void>();
    final runner = WalletBackupJobRunner(publish: () async => const Ok(null));

    final first = runner.run(() async {
      order.add('first started');
      await release.future;
      order.add('first finished');
      return const Ok(null);
    });
    final second = runner.run(() async {
      order.add('second started');
      return const Ok(null);
    });

    await pumpEventQueue();
    expect(order, ['first started']);

    release.complete();
    await Future.wait([first, second]);

    expect(order, ['first started', 'first finished', 'second started']);
  });

  test('a failing job does not wedge the queue', () async {
    final runner = WalletBackupJobRunner(publish: () async => const Ok(null));

    await expectLater(
      runner.run<void>(() async => throw StateError('boom')),
      throwsStateError,
    );

    expect(
      await runner.run(() async => const Ok(null)),
      isA<Ok<void, WalletBackupFailure>>(),
    );
  });

  test('triggers during a publication collapse into one more pass', () async {
    var passes = 0;
    late WalletBackupJobRunner runner;
    runner = WalletBackupJobRunner(
      publish: () async {
        passes++;
        if (passes == 1) {
          // Three more triggers while the first pass is in flight.
          runner.requestPublish();
          runner.requestPublish();
          runner.requestPublish();
        }
        return const Ok(null);
      },
    );

    await runner.requestPublish();

    expect(passes, 2);
  });

  test('callers joining a running publication share its result', () async {
    final release = Completer<void>();
    var passes = 0;
    final runner = WalletBackupJobRunner(
      publish: () async {
        passes++;
        await release.future;
        return const Err(WalletBackupRemoteUnavailableFailure());
      },
    );

    final first = runner.requestPublish();
    final second = runner.requestPublish();
    release.complete();

    expect(await first, isA<Err<void, WalletBackupFailure>>());
    expect(await second, isA<Err<void, WalletBackupFailure>>());
    expect(
      passes,
      1,
      reason: 'the second trigger arrived before the first ran',
    );
  });

  test('a rate-limited server closes the gate until it lifts', () async {
    var now = DateTime.utc(2026);
    var calls = 0;
    final runner = WalletBackupJobRunner(
      publish: () async {
        calls++;
        return calls == 1
            ? const Err(WalletBackupRateLimitedFailure(Duration(seconds: 30)))
            : const Ok(null);
      },
      now: () => now,
    );

    expect(
      await runner.requestPublish(),
      isA<Err<void, WalletBackupFailure>>(),
    );
    expect(calls, 1);

    // Nothing reaches the server while the gate is closed, publication and
    // other jobs alike.
    expect(
      await runner.requestPublish(),
      isA<Err<void, WalletBackupFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<WalletBackupRateLimitedFailure>(),
      ),
    );
    expect(
      await runner.run(() async => const Ok(null)),
      isA<Err<void, WalletBackupFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<WalletBackupRateLimitedFailure>(),
      ),
    );
    expect(calls, 1);

    now = now.add(const Duration(seconds: 30));

    expect(await runner.requestPublish(), isA<Ok<void, WalletBackupFailure>>());
    expect(calls, 2);
  });

  test('the gate is not durable: a fresh runner starts open', () async {
    final now = DateTime.utc(2026);
    var calls = 0;
    Future<Result<void, WalletBackupFailure>> publish() async {
      calls++;
      return calls == 1
          ? const Err(WalletBackupRateLimitedFailure(Duration(seconds: 30)))
          : const Ok(null);
    }

    final first = WalletBackupJobRunner(publish: publish, now: () => now);
    await first.requestPublish();
    await first.dispose();

    final restarted = WalletBackupJobRunner(publish: publish, now: () => now);

    expect(
      await restarted.requestPublish(),
      isA<Ok<void, WalletBackupFailure>>(),
    );
    expect(calls, 2);
  });
}

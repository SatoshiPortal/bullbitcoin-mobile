import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_state.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../sp_cubit_harness.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet_data.dart';

void main() {
  late SpCubitHarness harness;
  late StreamController<SpNotification> notifications;
  late SpCubit cubit;

  // Matches SpCubit._headerRetryBackoff and _maxHeaderRetries.
  const backoff = Duration(seconds: 2);
  const maxRetries = 5;

  setUp(() {
    harness = SpCubitHarness();
    notifications = StreamController<SpNotification>.broadcast();
    when(
      () => harness.watchUsecase.execute(),
    ).thenAnswer((_) => notifications.stream);
    when(
      () => harness.loadUsecase.execute(),
    ).thenAnswer((_) async => Ok<SpWalletData, SpFailure>(spWalletData()));
    cubit = harness.build();
  });

  tearDown(() async {
    await notifications.close();
    await cubit.close();
  });

  Future<void> subscribe() async {
    await cubit.load();
    await Future<void>.delayed(Duration.zero);
  }

  test('an initial sync failure shows reconnecting, not failed', () async {
    await subscribe();

    notifications.add(
      const SpHeaderProgressFailed(SpHeaderValidationPhase.initialSync),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      cubit.state.headerValidationStatus,
      SpHeaderValidationStatus.reconnecting,
    );
  });

  test('a replay failure fails straight away, no retry', () async {
    await subscribe();

    notifications.add(
      const SpHeaderProgressFailed(SpHeaderValidationPhase.replay),
    );
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.headerValidationStatus, SpHeaderValidationStatus.failed);
    verifyNever(() => harness.resyncUsecase.execute());
  });

  test('progress after a failure clears the reconnecting state', () async {
    await subscribe();

    notifications.add(
      const SpHeaderProgressFailed(SpHeaderValidationPhase.initialSync),
    );
    await Future<void>.delayed(Duration.zero);
    notifications.add(
      const SpHeaderProgressStarted(
        phase: SpHeaderValidationPhase.initialSync,
        start: 800000,
        end: 900000,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      cubit.state.headerValidationStatus,
      SpHeaderValidationStatus.validating,
    );
  });

  test('retries restart the listener, then escalate once spent', () {
    fakeAsync((async) {
      unawaited(cubit.load());
      async.flushMicrotasks();

      notifications.add(
        const SpHeaderProgressFailed(SpHeaderValidationPhase.initialSync),
      );
      async.flushMicrotasks();
      expect(
        cubit.state.headerValidationStatus,
        SpHeaderValidationStatus.reconnecting,
      );

      // Each backoff tick restarts the listener while attempts remain.
      for (var attempt = 1; attempt <= maxRetries; attempt++) {
        async.elapse(backoff);
        async.flushMicrotasks();
        verify(() => harness.resyncUsecase.execute()).called(1);
        expect(
          cubit.state.headerValidationStatus,
          SpHeaderValidationStatus.reconnecting,
          reason: 'still retrying after attempt $attempt',
        );
      }

      // The next tick has no attempts left, so the failure finally surfaces.
      async.elapse(backoff);
      async.flushMicrotasks();
      verifyNever(() => harness.resyncUsecase.execute());
      expect(
        cubit.state.headerValidationStatus,
        SpHeaderValidationStatus.failed,
      );
    });
  });

  test('a sync that keeps failing before any progress stops retrying', () {
    fakeAsync((async) {
      unawaited(cubit.load());
      async.flushMicrotasks();

      // A refused range of old headers: every restart starts it again and it
      // fails again, with no progress in between.
      void startThenFail() {
        notifications
          ..add(
            const SpHeaderProgressStarted(
              phase: SpHeaderValidationPhase.initialSync,
              start: 800000,
              end: 899999,
            ),
          )
          ..add(
            const SpHeaderProgressFailed(SpHeaderValidationPhase.initialSync),
          );
        async.flushMicrotasks();
      }

      startThenFail();
      for (var attempt = 1; attempt <= maxRetries; attempt++) {
        async.elapse(backoff);
        async.flushMicrotasks();
        startThenFail();
      }
      verify(() => harness.resyncUsecase.execute()).called(maxRetries);

      async.elapse(backoff * 10);
      async.flushMicrotasks();
      verifyNever(() => harness.resyncUsecase.execute());
      expect(
        cubit.state.headerValidationStatus,
        SpHeaderValidationStatus.failed,
      );
    });
  });

  test('progress after a restart stops the retries', () {
    fakeAsync((async) {
      unawaited(cubit.load());
      async.flushMicrotasks();

      notifications.add(
        const SpHeaderProgressFailed(SpHeaderValidationPhase.initialSync),
      );
      async.flushMicrotasks();
      async.elapse(backoff);
      async.flushMicrotasks();
      notifications
        ..add(
          const SpHeaderProgressStarted(
            phase: SpHeaderValidationPhase.initialSync,
            start: 900000,
            end: 970180,
          ),
        )
        ..add(
          const SpHeaderProgress(
            phase: SpHeaderValidationPhase.initialSync,
            current: 910000,
            end: 970180,
          ),
        );
      async.flushMicrotasks();

      expect(
        cubit.state.headerValidationStatus,
        SpHeaderValidationStatus.validating,
      );
      async.elapse(backoff * 10);
      async.flushMicrotasks();
      verify(() => harness.resyncUsecase.execute()).called(1);
    });
  });

  test('a header extension below the tip keeps the tip', () async {
    await subscribe();

    notifications
      ..add(
        const SpHeaderProgressStarted(
          phase: SpHeaderValidationPhase.initialSync,
          start: 900000,
          end: 970180,
        ),
      )
      ..add(
        const SpHeaderProgressCompleted(SpHeaderValidationPhase.initialSync),
      )
      // Extension down to an old coin: same phase, a range below the tip.
      ..add(
        const SpHeaderProgressStarted(
          phase: SpHeaderValidationPhase.initialSync,
          start: 800000,
          end: 899999,
        ),
      );
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.chainTip, 970180);
    expect(
      cubit.state.headerValidationStatus,
      SpHeaderValidationStatus.validating,
    );

    notifications.add(
      const SpHeaderProgressCompleted(SpHeaderValidationPhase.initialSync),
    );
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.chainTip, 970180);
    expect(cubit.state.headerValidationStatus, SpHeaderValidationStatus.valid);
  });

  group('checkpoint mismatch', () {
    test('cancels a pending retry and shows the invalid chain', () {
      fakeAsync((async) {
        unawaited(cubit.load());
        async.flushMicrotasks();

        // Failed can land before the mismatch: two bwk channels.
        notifications.add(
          const SpHeaderProgressFailed(SpHeaderValidationPhase.initialSync),
        );
        notifications.add(const SpHeaderCheckpointMismatch());
        async.flushMicrotasks();

        expect(
          cubit.state.headerValidationStatus,
          SpHeaderValidationStatus.invalidChain,
        );
        async.elapse(backoff * (maxRetries + 2));
        async.flushMicrotasks();
        verifyNever(() => harness.resyncUsecase.execute());
        expect(
          cubit.state.headerValidationStatus,
          SpHeaderValidationStatus.invalidChain,
        );
      });
    });

    test('later sync events and repeats do not retry or hide it', () {
      fakeAsync((async) {
        unawaited(cubit.load());
        async.flushMicrotasks();

        notifications.add(const SpHeaderCheckpointMismatch());
        notifications.add(
          const SpHeaderProgressStarted(
            phase: SpHeaderValidationPhase.initialSync,
            start: 800000,
            end: 900000,
          ),
        );
        notifications.add(
          const SpHeaderProgress(
            phase: SpHeaderValidationPhase.initialSync,
            current: 850000,
            end: 900000,
          ),
        );
        notifications.add(
          const SpHeaderProgressFailed(SpHeaderValidationPhase.initialSync),
        );
        notifications.add(const SpHeaderCheckpointMismatch());
        async.flushMicrotasks();
        async.elapse(backoff * (maxRetries + 2));
        async.flushMicrotasks();

        verifyNever(() => harness.resyncUsecase.execute());
        expect(
          cubit.state.headerValidationStatus,
          SpHeaderValidationStatus.invalidChain,
        );
      });
    });

    test('a completed sync clears it', () async {
      await subscribe();

      notifications.add(const SpHeaderCheckpointMismatch());
      notifications.add(
        const SpHeaderProgressCompleted(SpHeaderValidationPhase.initialSync),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        cubit.state.headerValidationStatus,
        SpHeaderValidationStatus.valid,
      );
    });

    test('a backend change clears it', () async {
      await subscribe();
      notifications.add(const SpHeaderCheckpointMismatch());
      await Future<void>.delayed(Duration.zero);

      await cubit.reloadAfterBackendChange();

      expect(cubit.state.headerValidationStatus, SpHeaderValidationStatus.idle);
      verify(() => harness.loadUsecase.execute()).called(2);
    });
  });
}

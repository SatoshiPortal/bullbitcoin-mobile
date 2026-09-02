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
}

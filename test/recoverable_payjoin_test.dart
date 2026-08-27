import 'dart:async';

import 'package:bb_mobile/recoverable_payjoin.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockPayjoinLifecycle extends Mock implements PayjoinLifecycle {}

class _MockPayjoinSender extends Mock implements PayjoinSender {}

class _MockPayjoinReceiver extends Mock implements PayjoinReceiver {}

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

class _MockPayjoinPolicy extends Mock implements PayjoinPolicyAccess {}

class _MockPayjoinDiagnostics extends Mock implements PayjoinDiagnostics {}

void main() {
  late _MockPayjoinLifecycle lifecycle;
  late _MockPayjoinSessions sessions;
  late Completer<void> resumed;

  setUp(() {
    lifecycle = _MockPayjoinLifecycle();
    sessions = _MockPayjoinSessions();
    resumed = Completer<void>();
    when(() => lifecycle.payjoin).thenReturn(
      Payjoin(
        sender: _MockPayjoinSender(),
        receiver: _MockPayjoinReceiver(),
        sessions: sessions,
        policy: _MockPayjoinPolicy(),
        diagnostics: _MockPayjoinDiagnostics(),
      ),
    );
    // Resuming replays sessions over the network (rebroadcasts included), so a
    // role call must never be made to wait on it.
    when(() => lifecycle.resume()).thenAnswer((_) async {
      await resumed.future;
      return const Ok<void, PayjoinFailure>(null);
    });
    when(() => lifecycle.dispose()).thenAnswer((_) async {});
    when(
      () => sessions.reservedOutpoints(),
    ).thenAnswer((_) async => const Ok(<Outpoint>{}));
  });

  test(
    'a role call issued before startup finished waits for the open',
    () async {
      final opening = Completer<Result<PayjoinLifecycle, PayjoinFailure>>();
      final runtime = RecoverablePayjoin(() => opening.future);
      addTearDown(() {
        if (!resumed.isCompleted) resumed.complete();
        return runtime.dispose();
      });
      unawaited(runtime.resume());

      final reserved = runtime.payjoin.sessions.reservedOutpoints();
      opening.complete(Ok(lifecycle));

      // Answering with the fail-closed Err here would strand every Bitcoin send:
      // PrepareBitcoinSendUsecase turns it into a build failure.
      expect(await reserved, isA<Ok<Set<Outpoint>, PayjoinFailure>>());
      // And the answer came from the open alone — the slow session resume is
      // still in flight.
      expect(resumed.isCompleted, isFalse);
    },
  );

  test('roles stay fail-closed while the storage cannot be opened', () async {
    final runtime = RecoverablePayjoin(
      () async => const Err<PayjoinLifecycle, PayjoinFailure>(
        PayjoinStorageFailure('database locked'),
      ),
    );
    addTearDown(runtime.dispose);

    expect(await runtime.resume(), isA<Err<void, PayjoinFailure>>());
    // Never an invented empty set: those outpoints may be reserved by a
    // session this build cannot read.
    expect(
      await runtime.payjoin.sessions.reservedOutpoints(),
      isA<Err<Set<Outpoint>, PayjoinFailure>>(),
    );
  });

  test('a failed open is retried on resume, not on every role call', () async {
    var attempts = 0;
    final runtime = RecoverablePayjoin(() async {
      attempts++;
      if (attempts == 1) {
        return const Err<PayjoinLifecycle, PayjoinFailure>(
          PayjoinStorageFailure('database locked'),
        );
      }
      return Ok(lifecycle);
    });
    addTearDown(() {
      if (!resumed.isCompleted) resumed.complete();
      return runtime.dispose();
    });
    final injectedSessions = runtime.payjoin.sessions;

    expect(await runtime.resume(), isA<Err<void, PayjoinFailure>>());
    expect(await injectedSessions.reservedOutpoints(), isA<Err>());
    expect(attempts, 1, reason: 'a role call must not hammer a failed open');

    unawaited(runtime.resume());
    await pumpEventQueue();

    // The reference features were injected with at startup recovers in place.
    expect(runtime.payjoin.sessions, same(injectedSessions));
    expect(await injectedSessions.reservedOutpoints(), isA<Ok>());
    expect(attempts, 2);
  });

  test('concurrent resumes open the storage once', () async {
    var attempts = 0;
    final opening = Completer<Result<PayjoinLifecycle, PayjoinFailure>>();
    final runtime = RecoverablePayjoin(() {
      attempts++;
      return opening.future;
    });
    addTearDown(() {
      if (!resumed.isCompleted) resumed.complete();
      return runtime.dispose();
    });

    final first = runtime.resume();
    final second = runtime.resume();
    opening.complete(Ok(lifecycle));
    resumed.complete();

    expect(await first, isA<Ok<void, PayjoinFailure>>());
    expect(await second, isA<Ok<void, PayjoinFailure>>());
    expect(attempts, 1);
    verify(() => lifecycle.resume()).called(1);
  });
}

import 'dart:async';

import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:test/test.dart';
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
    when(() => sessions.reservedOutpoints())
        .thenAnswer((_) async => const Ok(<Outpoint>{}));
  });

  for (final capturedRegtest in [false, true]) {
    test(
      'stale runtime family refuses roles and recovery regtest=$capturedRegtest',
      () async {
        var activeRegtest = capturedRegtest;
        final runtime = RecoverablePayjoin(
          () async => Ok(lifecycle),
          isCurrent: () async => activeRegtest == capturedRegtest,
        );
        addTearDown(runtime.dispose);
        expect(await runtime.payjoin.sessions.reservedOutpoints(), isA<Ok>());
        verify(() => sessions.reservedOutpoints()).called(1);
        activeRegtest = !capturedRegtest;
        final result = await runtime.payjoin.sessions.reservedOutpoints();
        expect(result, isA<Err>());
        expect(
          (result as Err<Set<Outpoint>, PayjoinFailure>).failure,
          isA<PayjoinUnavailableFailure>(),
        );
        expect(await runtime.resume(), isA<Err<void, PayjoinFailure>>());
        final senderResult = await runtime.payjoin.sender.start(
          StartPayjoinSender(
            walletId: 'wallet',
            network: capturedRegtest
                ? BitcoinNetwork.regtest
                : BitcoinNetwork.mainnet,
            bip21Uri: 'bitcoin:fixture',
            unsignedOriginalPsbt: 'unused',
            amount: Sats.fromInt(10000),
            feeRate: FeeRate(1),
          ),
        );
        expect(
          (senderResult as Err<PayjoinSenderSession, PayjoinFailure>).failure,
          isA<PayjoinUnavailableFailure>(),
        );
        expect(
          await runtime.payjoin.diagnostics.relayHealth(),
          isA<Err<PayjoinRelayHealth, PayjoinFailure>>(),
        );
        expect(
          await runtime.payjoin.policy.setActionEnabled(
            PayjoinAction.send,
            enabled: false,
          ),
          isA<Err<PayjoinPolicy, PayjoinFailure>>(),
        );
        verifyZeroInteractions(lifecycle.payjoin.sender);
        verifyZeroInteractions(lifecycle.payjoin.diagnostics);
        verifyZeroInteractions(lifecycle.payjoin.policy);
        verifyNever(() => lifecycle.resume());
        verifyNoMoreInteractions(sessions);
      },
    );
  }

  test('a role call issued before startup finished waits for the open', () async {
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
  });

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

  test(
    'suspend closes the open storage, refuses roles and resume until reopened',
    () async {
      var opens = 0;
      final runtime = RecoverablePayjoin(() async {
        opens++;
        return Ok(lifecycle);
      });
      addTearDown(runtime.dispose);
      expect(await runtime.payjoin.sessions.reservedOutpoints(), isA<Ok>());

      final stopGate = Completer<void>();
      when(() => lifecycle.dispose()).thenAnswer((_) => stopGate.future);
      var confirmed = false;
      final suspending = runtime.suspend().whenComplete(() => confirmed = true);

      expect(
        await runtime.payjoin.sessions.reservedOutpoints(),
        isA<Err>(),
        reason: 'revoked before the stop is confirmed',
      );
      expect(await runtime.resume(), isA<Err>());
      runtime.reopen();
      expect(
        await runtime.resume(),
        isA<Err>(),
        reason: 'stop not confirmed yet',
      );
      await Future<void>.delayed(Duration.zero);
      expect(confirmed, isFalse);
      expect(opens, 1, reason: 'no second instance beside the closing one');

      stopGate.complete();
      await suspending;
      verify(() => lifecycle.dispose()).called(1);

      runtime.reopen();
      resumed.complete();
      expect(await runtime.resume(), isA<Ok>());
      expect(opens, 2);
      expect(await runtime.payjoin.sessions.reservedOutpoints(), isA<Ok>());
    },
  );

  test(
    'suspending while the storage opens disposes what it produced',
    () async {
      final opening = Completer<Result<PayjoinLifecycle, PayjoinFailure>>();
      final runtime = RecoverablePayjoin(() => opening.future);
      addTearDown(runtime.dispose);
      final call = runtime.payjoin.sessions.reservedOutpoints();
      final suspending = runtime.suspend();
      opening.complete(Ok(lifecycle));
      await suspending;
      expect(await call, isA<Err>());
      verify(() => lifecycle.dispose()).called(1);
    },
  );

  group('suspension generations', () {
    late _MockPayjoinSender sender;
    late _MockPayjoinLifecycle engine;
    const engineResult = PayjoinUnexpectedFailure('the engine answered');

    setUp(() {
      sender = _MockPayjoinSender();
      engine = _MockPayjoinLifecycle();
      when(() => engine.payjoin).thenReturn(
        Payjoin(
          sender: sender,
          receiver: _MockPayjoinReceiver(),
          sessions: sessions,
          policy: _MockPayjoinPolicy(),
          diagnostics: _MockPayjoinDiagnostics(),
        ),
      );
      when(() => engine.resume())
          .thenAnswer((_) async => const Ok<void, PayjoinFailure>(null));
      when(() => engine.dispose()).thenAnswer((_) async {});
    });

    test(
      'a resume held on the family check does not resume after a lock',
      () async {
        final family = Completer<bool>();
        var opens = 0;
        final runtime = RecoverablePayjoin(() async {
          opens++;
          return Ok(engine);
        }, isCurrent: () => family.future);
        addTearDown(runtime.dispose);

        final resuming = runtime.resume();
        await Future<void>.delayed(Duration.zero);
        final suspending = runtime.suspend();
        family.complete(true);

        expect(await resuming, isA<Err>());
        await suspending;
        verifyNever(() => engine.resume());
        expect(opens, 1);
      },
    );

    test('a role call held on the family check never reaches the engine after a lock', () async {
      final family = Completer<bool>();
      final runtime = RecoverablePayjoin(
        () async => Ok(engine),
        isCurrent: () => family.future,
      );
      addTearDown(runtime.dispose);

      final call = runtime.payjoin.sessions.reservedOutpoints();
      await Future<void>.delayed(Duration.zero);
      final suspending = runtime.suspend();
      family.complete(true);

      expect(await call, isA<Err>());
      await suspending;
      verifyNever(() => sessions.reservedOutpoints());
      expect(
        await runtime.payjoin.sessions.reservedOutpoints(),
        isA<Err>(),
        reason: 'no delegate of the revoked generation is reinstalled',
      );
    });

    test(
      'a broadcast already admitted returns its real result and holds the stop',
      () async {
        var opens = 0;
        final runtime = RecoverablePayjoin(() async {
          opens++;
          return Ok(engine);
        });
        addTearDown(runtime.dispose);
        expect(await runtime.payjoin.sessions.reservedOutpoints(), isA<Ok>());
        final inEngine = Completer<Result<PayjoinSession, PayjoinFailure>>();
        when(() => sender.broadcastOriginal('s'))
            .thenAnswer((_) => inEngine.future);

        final broadcast = runtime.payjoin.sender.broadcastOriginal('s');
        await Future<void>.delayed(Duration.zero);
        verify(() => sender.broadcastOriginal('s')).called(1);

        var confirmed = false;
        final suspending = runtime.suspend().whenComplete(
          () => confirmed = true,
        );
        await Future<void>.delayed(Duration.zero);
        expect(confirmed, isFalse, reason: 'the effect is still running');
        verifyNever(() => engine.dispose());
        runtime.reopen();
        expect(
          await runtime.resume(),
          isA<Err>(),
          reason: 'no second instance yet',
        );
        expect(opens, 1);

        inEngine.complete(const Err(engineResult));
        final result = await broadcast;
        expect((result as Err).failure, same(engineResult));
        await suspending;
        verify(() => engine.dispose()).called(1);

        runtime.reopen();
        resumed.complete();
        expect(await runtime.resume(), isA<Ok>());
        expect(opens, 2);
      },
    );

    test('a broadcast not yet admitted is blocked by the lock', () async {
      final family = Completer<bool>();
      final runtime = RecoverablePayjoin(
        () async => Ok(engine),
        isCurrent: () => family.future,
      );
      addTearDown(runtime.dispose);

      final broadcast = runtime.payjoin.sender.broadcastOriginal('s');
      await Future<void>.delayed(Duration.zero);
      final suspending = runtime.suspend();
      family.complete(true);

      expect(await broadcast, isA<Err>());
      await suspending;
      verifyNever(() => sender.broadcastOriginal(any()));
    });

    test(
      'a new sensitive call after the lock is refused before any await',
      () async {
        final runtime = RecoverablePayjoin(() async => Ok(engine));
        addTearDown(runtime.dispose);
        expect(await runtime.payjoin.sessions.reservedOutpoints(), isA<Ok>());
        final suspending = runtime.suspend();
        final late = runtime.payjoin.sender.broadcastOriginal('s');
        expect(await late, isA<Err>());
        await suspending;
        verifyNever(() => sender.broadcastOriginal(any()));
      },
    );
  });
}

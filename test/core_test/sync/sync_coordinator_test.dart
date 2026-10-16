import 'dart:async';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';

import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/sync/sync_kind.dart';
import 'package:bb_mobile/core/sync/sync_trigger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWallets extends Mock implements GetWalletsUsecase {}

class _MockSyncWallet extends Mock implements SyncWalletUsecase {}

class _RecordingSyncWallet extends Mock implements SyncWalletUsecase {
  final discoveries = <bool>[];
  Future<void>? gate;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #execute) {
      discoveries.add(invocation.namedArguments[#fullDiscovery] == true);
      return gate ?? Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _MockWallet extends Mock implements Wallet {}

class _MockSyncSwaps extends Mock {
  Future<void> call();
}

void main() {
  // SyncCoordinator's constructor reads WidgetsBinding.instance and attaches
  // an AppLifecycleListener, so the binding must exist.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockGetWallets getWallets;
  late _MockSyncWallet syncWallet;
  late _MockSyncSwaps syncSwaps;
  late SyncCoordinator coordinator;
  late Future<void> Function() spCallback;

  setUp(() {
    getWallets = _MockGetWallets();
    syncWallet = _MockSyncWallet();
    syncSwaps = _MockSyncSwaps();
    when(syncSwaps.call).thenAnswer((_) async {});
    spCallback = () async {};
    coordinator = SyncCoordinator(
      getWalletsUsecase: getWallets,
      syncWalletUsecase: syncWallet,
      syncSwaps: syncSwaps.call,
      // Deferred so a test can swap the behaviour after construction, the way
      // the composition root's lazy closure resolves the facade at call time.
      syncSp: () => spCallback(),
    );
  });

  tearDown(() => coordinator.dispose());

  // Each kind's work is gated behind a Completer so the test controls exactly
  // when bitcoin / liquid / sp finish. The wallet list is empty, so no real
  // Wallet needs constructing — the gate alone paces the drain.
  ({Completer<void> bitcoin, Completer<void> liquid, Completer<void> sp})
  wireGates() {
    final bitcoin = Completer<void>();
    final liquid = Completer<void>();
    final sp = Completer<void>();
    when(() => getWallets.execute(onlyBitcoin: true)).thenAnswer((_) async {
      await bitcoin.future;
      return const Ok<List<Wallet>, WalletFailure>([]);
    });
    when(() => getWallets.execute(onlyLiquid: true)).thenAnswer((_) async {
      await liquid.future;
      return const Ok<List<Wallet>, WalletFailure>([]);
    });
    spCallback = () async {
      await sp.future;
    };
    return (bitcoin: bitcoin, liquid: liquid, sp: sp);
  }

  test('manual discovery applies to bitcoin only', () async {
    final recording = _RecordingSyncWallet();
    final manual = SyncCoordinator(
      getWalletsUsecase: getWallets,
      syncWalletUsecase: recording,
    );
    addTearDown(manual.dispose);
    when(
      () => getWallets.execute(onlyBitcoin: true),
    ).thenAnswer((_) async => Ok([_MockWallet()]));

    when(
      () => getWallets.execute(onlyLiquid: true),
    ).thenAnswer((_) async => Ok([_MockWallet()]));
    await manual.sync(trigger: SyncTrigger.user);

    expect(recording.discoveries, [true, false]);
  });

  test(
    'manual discovery waits for its follow-up after an automatic sync',
    () async {
      final recording = _RecordingSyncWallet();
      final automaticGate = Completer<void>();
      final discoveryGate = Completer<void>();
      recording.gate = automaticGate.future;
      final manual = SyncCoordinator(
        getWalletsUsecase: getWallets,
        syncWalletUsecase: recording,
      );
      addTearDown(manual.dispose);
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => Ok([_MockWallet()]));
      final automatic = manual.sync(only: {SyncKind.bitcoin});
      await pumpEventQueue();
      expect(recording.discoveries, [false]);
      var manualDone = false;
      final discovery = manual
          .sync(only: {SyncKind.bitcoin}, trigger: SyncTrigger.user)
          .then((_) => manualDone = true);
      recording.gate = discoveryGate.future;
      automaticGate.complete();
      await automatic;
      await pumpEventQueue();

      expect(recording.discoveries, [false, true]);
      expect(manualDone, isFalse);
      discoveryGate.complete();
      await discovery;
      expect(manualDone, isTrue);
    },
  );

  test(
    'manual discovery upgrades an automatic bitcoin sync still queued',
    () async {
      final recording = _RecordingSyncWallet();
      final gate = Completer<void>();
      final manual = SyncCoordinator(
        getWalletsUsecase: getWallets,
        syncWalletUsecase: recording,
      );
      addTearDown(manual.dispose);
      when(() => getWallets.execute(onlyLiquid: true)).thenAnswer((_) async {
        await gate.future;
        return const Ok<List<Wallet>, WalletFailure>([]);
      });
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => Ok([_MockWallet()]));
      final liquid = manual.sync(only: {SyncKind.liquid});
      final automatic = manual.sync(only: {SyncKind.bitcoin});
      final discovery = manual.sync(
        only: {SyncKind.bitcoin},
        trigger: SyncTrigger.user,
      );
      gate.complete();
      await Future.wait([liquid, automatic, discovery]);

      expect(recording.discoveries, [true]);
    },
  );

  test('concurrent manual discoveries join the running discovery', () async {
    final recording = _RecordingSyncWallet();
    final gate = Completer<void>();
    recording.gate = gate.future;
    final manual = SyncCoordinator(
      getWalletsUsecase: getWallets,
      syncWalletUsecase: recording,
    );
    addTearDown(manual.dispose);
    when(
      () => getWallets.execute(onlyBitcoin: true),
    ).thenAnswer((_) async => Ok([_MockWallet()]));
    final first = manual.sync(
      only: {SyncKind.bitcoin},
      trigger: SyncTrigger.user,
    );
    await pumpEventQueue();
    final second = manual.sync(
      only: {SyncKind.bitcoin},
      trigger: SyncTrigger.user,
    );
    gate.complete();
    await Future.wait([first, second]);

    expect(recording.discoveries, [true]);
  });

  for (final fails in [false, true]) {
    test(
      'two pulls wait for discovery after automatic sync (fails=$fails)',
      () async {
        final recording = _RecordingSyncWallet();
        final automaticGate = Completer<void>();
        final discoveryGate = Completer<void>();
        recording.gate = automaticGate.future;
        final manual = SyncCoordinator(
          getWalletsUsecase: getWallets,
          syncWalletUsecase: recording,
        );
        addTearDown(manual.dispose);
        when(
          () => getWallets.execute(onlyBitcoin: true),
        ).thenAnswer((_) async => Ok([_MockWallet()]));
        Object? failure;
        var automaticDone = false;
        final automatic = manual
            .sync(only: {SyncKind.bitcoin})
            .then(
              (_) {
                automaticDone = true;
              },
              onError: (Object error) {
                failure = error;
                automaticDone = true;
              },
            );
        await pumpEventQueue();
        var firstDone = false;
        var secondDone = false;
        final first = manual
            .sync(only: {SyncKind.bitcoin}, trigger: SyncTrigger.user)
            .then((_) => firstDone = true);
        final second = manual
            .sync(only: {SyncKind.bitcoin}, trigger: SyncTrigger.user)
            .then((_) => secondDone = true);
        var joinedDone = false;
        final joined = manual
            .sync(only: {SyncKind.bitcoin})
            .then(
              (_) {
                joinedDone = true;
              },
              onError: (Object _) {
                joinedDone = true;
              },
            );
        recording.gate = discoveryGate.future;
        if (fails) {
          automaticGate.completeError(StateError('automatic failed'));
        } else {
          automaticGate.complete();
        }
        await automatic;
        await joined;
        await pumpEventQueue();
        expect(automaticDone, isTrue);
        expect(joinedDone, isTrue);
        expect(failure, fails ? isA<SyncCoordinatorException>() : isNull);
        expect(recording.discoveries, [false, true]);
        expect(firstDone, isFalse);
        expect(secondDone, isFalse);
        discoveryGate.complete();
        await Future.wait([first, second]);
        expect(firstDone && secondDone, isTrue);
        expect(recording.discoveries, [false, true]);
      },
    );
  }

  test('automatic sync joins a running pull and shares its failure', () async {
    final recording = _RecordingSyncWallet();
    final gate = Completer<void>();
    recording.gate = gate.future;
    final manual = SyncCoordinator(
      getWalletsUsecase: getWallets,
      syncWalletUsecase: recording,
    );
    addTearDown(manual.dispose);
    when(
      () => getWallets.execute(onlyBitcoin: true),
    ).thenAnswer((_) async => Ok([_MockWallet()]));
    var firstDone = false;
    var joinedDone = false;
    final failures = <Object>[];
    final first = manual
        .sync(only: {SyncKind.bitcoin}, trigger: SyncTrigger.user)
        .then(
          (_) {
            firstDone = true;
          },
          onError: (Object error) {
            failures.add(error);
            firstDone = true;
          },
        );
    await pumpEventQueue();
    final joined = manual
        .sync(only: {SyncKind.bitcoin})
        .then(
          (_) {
            joinedDone = true;
          },
          onError: (Object error) {
            failures.add(error);
            joinedDone = true;
          },
        );
    await pumpEventQueue();
    expect(firstDone || joinedDone, isFalse);
    expect(recording.discoveries, [true]);
    gate.completeError(StateError('pull failed'));
    await Future.wait([first, joined]);
    expect(firstDone && joinedDone, isTrue);
    expect(failures, everyElement(isA<SyncCoordinatorException>()));
    expect(failures, hasLength(2));
    expect(recording.discoveries, [true]);
  });

  test('sync resolves only after every requested kind has settled', () async {
    final gates = wireGates();

    var done = false;
    final future = coordinator
        .sync(trigger: SyncTrigger.automatic)
        .then((_) => done = true);

    await pumpEventQueue();
    expect(done, isFalse, reason: 'bitcoin still in flight');

    gates.bitcoin.complete();
    await pumpEventQueue();
    expect(done, isFalse, reason: 'liquid still in flight');

    gates.liquid.complete();
    await pumpEventQueue();
    expect(done, isFalse, reason: 'sp still in flight');

    gates.sp.complete();
    await future;
    expect(done, isTrue);
  });

  test(
    'a sync awaits the kinds IT requested even when it joins an in-flight '
    'drain that is about to finish (regression: spinner stopped after bitcoin)',
    () async {
      final gates = wireGates();

      // First caller drains bitcoin only.
      var firstDone = false;
      final first = coordinator
          .sync(only: {SyncKind.bitcoin})
          .then((_) => firstDone = true);
      await pumpEventQueue(); // bitcoin now running, gated.

      // Second caller joins while bitcoin is in flight and adds liquid.
      var secondDone = false;
      final second = coordinator
          .sync(only: {SyncKind.liquid})
          .then((_) => secondDone = true);

      gates.bitcoin.complete();
      await first;
      expect(firstDone, isTrue, reason: 'first only asked for bitcoin');
      expect(secondDone, isFalse, reason: 'liquid still pending');

      gates.liquid.complete();
      await second;
      expect(secondDone, isTrue);
    },
  );

  test('automatic re-sync within the throttle window is skipped; '
      'a user sync bypasses it', () async {
    // No gating: each kind completes immediately so _lastSuccessAt is set.
    when(
      () => getWallets.execute(onlyBitcoin: true),
    ).thenAnswer((_) async => Ok(<Wallet>[]));
    when(
      () => getWallets.execute(onlyLiquid: true),
    ).thenAnswer((_) async => Ok(<Wallet>[]));
    await coordinator.sync(trigger: SyncTrigger.automatic);
    // Immediately again (well within the 2s window); every kind is throttled.
    await coordinator.sync(trigger: SyncTrigger.automatic);

    verify(() => getWallets.execute(onlyBitcoin: true)).called(1);
    verify(() => getWallets.execute(onlyLiquid: true)).called(1);
    verifyNever(syncSwaps.call);
    // A user gesture bypasses the throttle and re-runs every kind.
    await coordinator.sync(trigger: SyncTrigger.user);

    verify(() => getWallets.execute(onlyBitcoin: true)).called(1);
    verify(() => getWallets.execute(onlyLiquid: true)).called(1);
    verifyNever(syncSwaps.call);
  });

  test(
    'a failed wallet read fails the round and does not arm the throttle',
    () async {
      // Degrading the failure to an empty list would let the round complete
      // normally, stamping _lastSuccessAt — so the sync would be reported as
      // successful AND the throttle would then suppress the retry that would
      // recover from a transient read failure.
      when(() => getWallets.execute(onlyBitcoin: true)).thenAnswer(
        (_) async => const Err<List<Wallet>, WalletFailure>(
          WalletStorageFailure('SqliteException(11): disk image is malformed'),
        ),
      );
      when(
        () => getWallets.execute(onlyLiquid: true),
      ).thenAnswer((_) async => Ok(<Wallet>[]));

      await expectLater(
        coordinator.sync(trigger: SyncTrigger.automatic),
        throwsA(isA<Exception>()),
      );

      // Not throttled away: the next automatic round retries bitcoin.
      await coordinator.sync(trigger: SyncTrigger.automatic).catchError((_) {});

      verify(() => getWallets.execute(onlyBitcoin: true)).called(2);
    },
  );

  test('a general sync does not wait for swap polling', () async {
    final order = <String>[];
    when(() => getWallets.execute(onlyBitcoin: true)).thenAnswer((_) async {
      order.add('bitcoin');
      return const Ok<List<Wallet>, WalletFailure>([]);
    });
    when(() => getWallets.execute(onlyLiquid: true)).thenAnswer((_) async {
      order.add('liquid');
      return const Ok<List<Wallet>, WalletFailure>([]);
    });
    when(syncSwaps.call).thenAnswer((_) async => order.add('swaps'));

    await coordinator.sync(trigger: SyncTrigger.user);

    expect(order, ['bitcoin', 'liquid']);
    verifyNever(syncSwaps.call);
  });

  test('deduplicates concurrent swap syncs', () async {
    final gate = Completer<void>();
    when(syncSwaps.call).thenAnswer((_) => gate.future);

    final first = coordinator.sync(
      only: {SyncKind.swaps},
      trigger: SyncTrigger.user,
    );
    final second = coordinator.sync(
      only: {SyncKind.swaps},
      trigger: SyncTrigger.user,
    );
    await pumpEventQueue();

    verify(syncSwaps.call).called(1);
    gate.complete();
    await Future.wait([first, second]);
  });

  test('does not sync swaps while the app is paused', () async {
    when(
      () => getWallets.execute(onlyBitcoin: true),
    ).thenAnswer((_) async => Ok(<Wallet>[]));
    when(
      () => getWallets.execute(onlyLiquid: true),
    ).thenAnswer((_) async => Ok(<Wallet>[]));
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );

    await coordinator.sync(only: {SyncKind.swaps}, trigger: SyncTrigger.user);

    verifyNever(syncSwaps.call);
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await pumpEventQueue();
  });

  group('SyncKind.sp', () {
    test('sync() invokes the registered syncSp once', () async {
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => Ok(<Wallet>[]));
      when(
        () => getWallets.execute(onlyLiquid: true),
      ).thenAnswer((_) async => Ok(<Wallet>[]));
      when(syncSwaps.call).thenAnswer((_) async {});
      var spCalls = 0;
      spCallback = () async => spCalls++;

      await coordinator.sync(only: {SyncKind.sp}, trigger: SyncTrigger.user);

      expect(spCalls, 1);
    });

    test('a syncSp throw does not sink bitcoin/liquid and '
        'surfaces as the sp failure', () async {
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => Ok(<Wallet>[]));
      when(
        () => getWallets.execute(onlyLiquid: true),
      ).thenAnswer((_) async => Ok(<Wallet>[]));
      when(syncSwaps.call).thenAnswer((_) async {});
      spCallback = () async => throw Exception('sp boom');

      Object? thrown;
      try {
        await coordinator.sync(trigger: SyncTrigger.automatic);
      } catch (e) {
        thrown = e;
      }

      // The other kinds still ran to completion despite sp failing.
      verify(() => getWallets.execute(onlyBitcoin: true)).called(1);
      verify(() => getWallets.execute(onlyLiquid: true)).called(1);
      // sp's failure is reported, not swallowed, and is the only failed kind.
      expect(thrown, isA<SyncCoordinatorException>());
      final failures = (thrown! as SyncCoordinatorException).failures;
      expect(failures.keys, [SyncKind.sp]);
    });

    test('sp is throttled like the others: an automatic re-sync within the '
        'window is skipped; a user sync bypasses it', () async {
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => Ok(<Wallet>[]));
      when(
        () => getWallets.execute(onlyLiquid: true),
      ).thenAnswer((_) async => Ok(<Wallet>[]));
      when(syncSwaps.call).thenAnswer((_) async {});
      var spCalls = 0;
      spCallback = () async => spCalls++;

      await coordinator.sync(trigger: SyncTrigger.automatic);
      await coordinator.sync(trigger: SyncTrigger.automatic);
      expect(spCalls, 1, reason: 'second automatic sp sync is throttled');

      await coordinator.sync(only: {SyncKind.sp}, trigger: SyncTrigger.user);
      expect(spCalls, 2, reason: 'a user sync bypasses the sp throttle');
    });

    test('a user sync leaves sp out unless asked for it', () async {
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => Ok(<Wallet>[]));
      when(
        () => getWallets.execute(onlyLiquid: true),
      ).thenAnswer((_) async => Ok(<Wallet>[]));
      var spCalls = 0;
      spCallback = () async => spCalls++;

      await coordinator.sync(trigger: SyncTrigger.user);

      verify(() => getWallets.execute(onlyBitcoin: true)).called(1);
      verify(() => getWallets.execute(onlyLiquid: true)).called(1);
      expect(spCalls, 0);
    });
  });
}

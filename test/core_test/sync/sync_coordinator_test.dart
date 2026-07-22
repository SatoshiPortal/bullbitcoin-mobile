import 'dart:async';

import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/sync/sync_kind.dart';
import 'package:bb_mobile/core/sync/sync_trigger.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWallets extends Mock implements GetWalletsUsecase {}

class _MockSyncWallet extends Mock implements SyncWalletUsecase {}

class _MockRestartSwaps extends Mock implements RestartSwapWatcherUsecase {}

void main() {
  // SyncCoordinator's constructor reads WidgetsBinding.instance and attaches
  // an AppLifecycleListener, so the binding must exist.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockGetWallets getWallets;
  late _MockSyncWallet syncWallet;
  late _MockRestartSwaps restartSwaps;
  late SyncCoordinator coordinator;

  setUp(() {
    getWallets = _MockGetWallets();
    syncWallet = _MockSyncWallet();
    restartSwaps = _MockRestartSwaps();
    coordinator = SyncCoordinator(
      getWalletsUsecase: getWallets,
      syncWalletUsecase: syncWallet,
      restartSwapWatcherUsecase: restartSwaps,
    );
  });

  tearDown(() => coordinator.dispose());

  // Each kind's work is gated behind a Completer so the test controls exactly
  // when bitcoin / liquid / swaps / sp finish. The wallet list is empty, so no
  // real Wallet needs constructing; the gate alone paces the drain.
  ({
    Completer<void> bitcoin,
    Completer<void> liquid,
    Completer<void> swaps,
    Completer<void> sp,
  })
  wireGates() {
    final bitcoin = Completer<void>();
    final liquid = Completer<void>();
    final swaps = Completer<void>();
    final sp = Completer<void>();
    when(() => getWallets.execute(onlyBitcoin: true)).thenAnswer((_) async {
      await bitcoin.future;
      return <Wallet>[];
    });
    when(() => getWallets.execute(onlyLiquid: true)).thenAnswer((_) async {
      await liquid.future;
      return <Wallet>[];
    });
    when(() => restartSwaps.execute()).thenAnswer((_) async {
      await swaps.future;
    });
    coordinator.resyncSpListener = () async {
      await sp.future;
    };
    return (bitcoin: bitcoin, liquid: liquid, swaps: swaps, sp: sp);
  }

  test('sync resolves only after every requested kind has settled', () async {
    final gates = wireGates();

    var done = false;
    final future = coordinator
        .sync(trigger: SyncTrigger.user)
        .then((_) => done = true);

    await pumpEventQueue();
    expect(done, isFalse, reason: 'bitcoin still in flight');

    gates.bitcoin.complete();
    await pumpEventQueue();
    expect(done, isFalse, reason: 'liquid still in flight');

    gates.liquid.complete();
    await pumpEventQueue();
    expect(done, isFalse, reason: 'swaps still in flight');

    gates.swaps.complete();
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

      // Second caller joins while bitcoin is in flight and adds liquid + swaps.
      var secondDone = false;
      final second = coordinator
          .sync(only: {SyncKind.liquid, SyncKind.swaps})
          .then((_) => secondDone = true);

      gates.bitcoin.complete();
      await first;
      expect(firstDone, isTrue, reason: 'first only asked for bitcoin');
      expect(secondDone, isFalse, reason: 'liquid + swaps still pending');

      gates.liquid.complete();
      await pumpEventQueue();
      expect(secondDone, isFalse, reason: 'swaps still in flight');

      gates.swaps.complete();
      await second;
      expect(secondDone, isTrue);
    },
  );

  test('automatic re-sync within the throttle window is skipped; '
      'a user sync bypasses it', () async {
    // No gating: each kind completes immediately so _lastSuccessAt is set.
    when(
      () => getWallets.execute(onlyBitcoin: true),
    ).thenAnswer((_) async => <Wallet>[]);
    when(
      () => getWallets.execute(onlyLiquid: true),
    ).thenAnswer((_) async => <Wallet>[]);
    when(() => restartSwaps.execute()).thenAnswer((_) async {});

    await coordinator.sync(trigger: SyncTrigger.automatic);
    // Immediately again (well within the 2s window); every kind is throttled.
    await coordinator.sync(trigger: SyncTrigger.automatic);

    verify(() => getWallets.execute(onlyBitcoin: true)).called(1);
    verify(() => getWallets.execute(onlyLiquid: true)).called(1);
    verify(() => restartSwaps.execute()).called(1);

    // A user gesture bypasses the throttle and re-runs every kind.
    await coordinator.sync(trigger: SyncTrigger.user);

    verify(() => getWallets.execute(onlyBitcoin: true)).called(1);
    verify(() => getWallets.execute(onlyLiquid: true)).called(1);
    verify(() => restartSwaps.execute()).called(1);
  });

  group('SyncKind.sp', () {
    test('sync() invokes the registered resyncSpListener once', () async {
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => <Wallet>[]);
      when(
        () => getWallets.execute(onlyLiquid: true),
      ).thenAnswer((_) async => <Wallet>[]);
      when(() => restartSwaps.execute()).thenAnswer((_) async {});
      var spCalls = 0;
      coordinator.resyncSpListener = () async => spCalls++;

      await coordinator.sync(only: {SyncKind.sp}, trigger: SyncTrigger.user);

      expect(spCalls, 1);
    });

    test('a resyncSpListener throw does not sink bitcoin/liquid/swaps and '
        'surfaces as the sp failure', () async {
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => <Wallet>[]);
      when(
        () => getWallets.execute(onlyLiquid: true),
      ).thenAnswer((_) async => <Wallet>[]);
      when(() => restartSwaps.execute()).thenAnswer((_) async {});
      coordinator.resyncSpListener = () async => throw Exception('sp boom');

      Object? thrown;
      try {
        await coordinator.sync(trigger: SyncTrigger.user);
      } catch (e) {
        thrown = e;
      }

      // The other three kinds still ran to completion despite sp failing.
      verify(() => getWallets.execute(onlyBitcoin: true)).called(1);
      verify(() => getWallets.execute(onlyLiquid: true)).called(1);
      verify(() => restartSwaps.execute()).called(1);
      // sp's failure is reported, not swallowed, and is the only failed kind.
      expect(thrown, isA<SyncCoordinatorException>());
      final failures = (thrown! as SyncCoordinatorException).failures;
      expect(failures.keys, [SyncKind.sp]);
    });

    test('sp is throttled like the others: an automatic re-sync within the '
        'window is skipped; a user sync bypasses it', () async {
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => <Wallet>[]);
      when(
        () => getWallets.execute(onlyLiquid: true),
      ).thenAnswer((_) async => <Wallet>[]);
      when(() => restartSwaps.execute()).thenAnswer((_) async {});
      var spCalls = 0;
      coordinator.resyncSpListener = () async => spCalls++;

      await coordinator.sync(trigger: SyncTrigger.automatic);
      await coordinator.sync(trigger: SyncTrigger.automatic);
      expect(spCalls, 1, reason: 'second automatic sp sync is throttled');

      await coordinator.sync(trigger: SyncTrigger.user);
      expect(spCalls, 2, reason: 'a user sync bypasses the sp throttle');
    });
  });
}

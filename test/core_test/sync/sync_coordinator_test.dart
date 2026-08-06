import 'dart:async';

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

  setUp(() {
    getWallets = _MockGetWallets();
    syncWallet = _MockSyncWallet();
    syncSwaps = _MockSyncSwaps();
    when(syncSwaps.call).thenAnswer((_) async {});
    coordinator = SyncCoordinator(
      getWalletsUsecase: getWallets,
      syncWalletUsecase: syncWallet,
      syncSwaps: syncSwaps.call,
    );
  });

  tearDown(() => coordinator.dispose());

  // Each kind's work is gated behind a Completer so the test controls exactly
  // when bitcoin / liquid finish. The wallet list is empty, so no real
  // Wallet needs constructing — the gate alone paces the drain.
  ({Completer<void> bitcoin, Completer<void> liquid}) wireGates() {
    final bitcoin = Completer<void>();
    final liquid = Completer<void>();
    when(() => getWallets.execute(onlyBitcoin: true)).thenAnswer((_) async {
      await bitcoin.future;
      return <Wallet>[];
    });
    when(() => getWallets.execute(onlyLiquid: true)).thenAnswer((_) async {
      await liquid.future;
      return <Wallet>[];
    });
    return (bitcoin: bitcoin, liquid: liquid);
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
    ).thenAnswer((_) async => <Wallet>[]);
    when(
      () => getWallets.execute(onlyLiquid: true),
    ).thenAnswer((_) async => <Wallet>[]);
    await coordinator.sync(trigger: SyncTrigger.automatic);
    // Immediately again (well within the 2s window) — every kind is throttled.
    await coordinator.sync(trigger: SyncTrigger.automatic);

    verify(() => getWallets.execute(onlyBitcoin: true)).called(1);
    verify(() => getWallets.execute(onlyLiquid: true)).called(1);
    verify(syncSwaps.call).called(1);
    // A user gesture bypasses the throttle and re-runs every kind.
    await coordinator.sync(trigger: SyncTrigger.user);

    verify(() => getWallets.execute(onlyBitcoin: true)).called(1);
    verify(() => getWallets.execute(onlyLiquid: true)).called(1);
    verify(syncSwaps.call).called(1);
  });

  test('runs bitcoin, liquid, then swaps', () async {
    final order = <String>[];
    when(() => getWallets.execute(onlyBitcoin: true)).thenAnswer((_) async {
      order.add('bitcoin');
      return <Wallet>[];
    });
    when(() => getWallets.execute(onlyLiquid: true)).thenAnswer((_) async {
      order.add('liquid');
      return <Wallet>[];
    });
    when(syncSwaps.call).thenAnswer((_) async => order.add('swaps'));

    await coordinator.sync(trigger: SyncTrigger.user);

    expect(order, ['bitcoin', 'liquid', 'swaps']);
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
    ).thenAnswer((_) async => <Wallet>[]);
    when(
      () => getWallets.execute(onlyLiquid: true),
    ).thenAnswer((_) async => <Wallet>[]);
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
}

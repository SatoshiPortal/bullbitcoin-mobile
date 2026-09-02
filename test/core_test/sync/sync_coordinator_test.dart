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
      return <Wallet>[];
    });
    when(() => getWallets.execute(onlyLiquid: true)).thenAnswer((_) async {
      await liquid.future;
      return <Wallet>[];
    });
    spCallback = () async {
      await sp.future;
    };
    return (bitcoin: bitcoin, liquid: liquid, sp: sp);
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
    ).thenAnswer((_) async => <Wallet>[]);
    when(
      () => getWallets.execute(onlyLiquid: true),
    ).thenAnswer((_) async => <Wallet>[]);
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

  test('a general sync does not wait for swap polling', () async {
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

  group('SyncKind.sp', () {
    test('sync() invokes the registered syncSp once', () async {
      when(
        () => getWallets.execute(onlyBitcoin: true),
      ).thenAnswer((_) async => <Wallet>[]);
      when(
        () => getWallets.execute(onlyLiquid: true),
      ).thenAnswer((_) async => <Wallet>[]);
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
      ).thenAnswer((_) async => <Wallet>[]);
      when(
        () => getWallets.execute(onlyLiquid: true),
      ).thenAnswer((_) async => <Wallet>[]);
      when(syncSwaps.call).thenAnswer((_) async {});
      spCallback = () async => throw Exception('sp boom');

      Object? thrown;
      try {
        await coordinator.sync(trigger: SyncTrigger.user);
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
      ).thenAnswer((_) async => <Wallet>[]);
      when(
        () => getWallets.execute(onlyLiquid: true),
      ).thenAnswer((_) async => <Wallet>[]);
      when(syncSwaps.call).thenAnswer((_) async {});
      var spCalls = 0;
      spCallback = () async => spCalls++;

      await coordinator.sync(trigger: SyncTrigger.automatic);
      await coordinator.sync(trigger: SyncTrigger.automatic);
      expect(spCalls, 1, reason: 'second automatic sp sync is throttled');

      await coordinator.sync(trigger: SyncTrigger.user);
      expect(spCalls, 2, reason: 'a user sync bypasses the sp throttle');
    });
  });
}

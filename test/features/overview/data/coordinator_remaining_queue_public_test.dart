import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a second caller awaits its own queued kind', () async {
    final bitcoin = Completer<void>();
    final liquid = Completer<void>();
    final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
      walletKey: (key) => key,
      classifyFailure: (failure) =>
          (empty: failure is SyncNotFoundFailure, code: failure.logCode),
      getWallets: ({onlyBitcoin, onlyLiquid}) async {
        await (onlyBitcoin == true ? bitcoin.future : liquid.future);
        return Ok(WalletRead([]));
      },
      syncWallet: (
        _, {
        discover = false,
        allowInitialScan = true,
        reason = SyncReason.auto,
      }) async {},
    );
    addTearDown(coordinator.dispose);
    var firstDone = false;
    var secondDone = false;
    final first = coordinator
        .sync(only: {SyncKind.bitcoin})
        .then((_) => firstDone = true);
    await pumpEventQueue();
    final second = coordinator
        .sync(only: {SyncKind.liquid})
        .then((_) => secondDone = true);
    bitcoin.complete();
    await first;
    expect(firstDone, isTrue);
    expect(secondDone, isFalse);
    liquid.complete();
    await second;
    expect(secondDone, isTrue);
  });

  test('failed inventory reads fail and immediately retry', () async {
    var reads = 0;
    final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
      walletKey: (key) => key,
      classifyFailure: (failure) =>
          (empty: failure is SyncNotFoundFailure, code: failure.logCode),
      getWallets: ({onlyBitcoin, onlyLiquid}) async {
        reads++;
        return const Err(SyncStorageFailure());
      },
      syncWallet: (
        _, {
        discover = false,
        allowInitialScan = true,
        reason = SyncReason.auto,
      }) async {},
    );
    addTearDown(coordinator.dispose);
    for (var i = 0; i < 2; i++) {
      await expectLater(
        coordinator.sync(only: {SyncKind.bitcoin}),
        throwsA(isA<SyncCoordinatorException>()),
      );
    }
    expect(reads, 2);
  });

  test(
    'user sync excludes swaps; concurrent explicit swaps coalesce',
    () async {
      final gate = Completer<void>();
      final reads = <String>[];
      var swaps = 0;
      final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
        walletKey: (key) => key,
        classifyFailure: (failure) =>
            (empty: failure is SyncNotFoundFailure, code: failure.logCode),
        getWallets: ({onlyBitcoin, onlyLiquid}) async {
          reads.add(onlyBitcoin == true ? 'bitcoin' : 'liquid');
          return Ok(WalletRead([]));
        },
        syncWallet: (
          _, {
          discover = false,
          allowInitialScan = true,
          reason = SyncReason.auto,
        }) async {},
        syncSwaps: () async {
          swaps++;
          await gate.future;
        },
      );
      addTearDown(coordinator.dispose);
      await coordinator.sync(trigger: SyncTrigger.user);
      expect(reads, ['bitcoin', 'liquid']);
      expect(swaps, 0);
      final first = coordinator.sync(
        only: {SyncKind.swaps},
        trigger: SyncTrigger.user,
      );
      final second = coordinator.sync(
        only: {SyncKind.swaps},
        trigger: SyncTrigger.user,
      );
      await pumpEventQueue();
      expect(swaps, 1);
      gate.complete();
      await Future.wait([first, second]);
      expect(swaps, 1);
    },
  );

  test('SP is explicit for user sync and automatic calls throttle', () async {
    var silent = 0;
    final reads = <String>[];
    final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
      walletKey: (key) => key,
      classifyFailure: (failure) =>
          (empty: failure is SyncNotFoundFailure, code: failure.logCode),
      getWallets: ({onlyBitcoin, onlyLiquid}) async {
        reads.add(onlyBitcoin == true ? 'bitcoin' : 'liquid');
        return Ok(WalletRead([]));
      },
      syncWallet: (
        _, {
        discover = false,
        allowInitialScan = true,
        reason = SyncReason.auto,
      }) async {},
      syncSp: () async => silent++,
    );
    addTearDown(coordinator.dispose);
    await coordinator.sync(trigger: SyncTrigger.user);
    expect(reads, ['bitcoin', 'liquid']);
    expect(silent, 0);
    await coordinator.sync(only: {SyncKind.sp});
    await coordinator.sync(only: {SyncKind.sp});
    expect(silent, 1);
    await coordinator.sync(only: {SyncKind.sp}, trigger: SyncTrigger.user);
    expect(silent, 2);
  });
}

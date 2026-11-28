import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'one activity interval and completion cover every requested kind',
    () async {
      final bitcoin = Completer<void>();
      final liquid = Completer<void>();
      final silent = Completer<void>();
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
        syncSp: () => silent.future,
      );
      addTearDown(coordinator.dispose);
      final activity = <bool>[];
      final subscription = coordinator.syncPassActivity.listen(activity.add);
      addTearDown(subscription.cancel);
      var done = false;
      final sync = coordinator
          .sync(only: {SyncKind.bitcoin, SyncKind.liquid, SyncKind.sp})
          .then((_) => done = true);
      await pumpEventQueue();
      expect(activity, [true]);
      expect(done, isFalse);
      bitcoin.complete();
      await pumpEventQueue();
      expect(done, isFalse);
      liquid.complete();
      await pumpEventQueue();
      expect(done, isFalse);
      silent.complete();
      await sync;
      await pumpEventQueue();
      expect(done, isTrue);
      expect(activity, [true, false]);
    },
  );

  test(
    'discovery is scoped by network and user pull bypasses throttling',
    () async {
      final mainnet = WalletKey(id: 'main', network: BitcoinNetwork.mainnet);
      final testnet = WalletKey(id: 'test', network: BitcoinNetwork.testnet);
      var environment = NetworkEnv.mainnet;
      var now = DateTime.utc(2026);
      final calls = <(WalletKey, bool, SyncReason)>[];
      final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
        walletKey: (key) => key,
        classifyFailure: (failure) =>
            (empty: failure is SyncNotFoundFailure, code: failure.logCode),
        readNetwork: () async => environment,
        now: () => now,
        getWallets: ({onlyBitcoin, onlyLiquid}) async => Ok(
          WalletRead([environment == NetworkEnv.mainnet ? mainnet : testnet]),
        ),
        syncWallet: (
          key, {
          discover = false,
          allowInitialScan = true,
          reason = SyncReason.auto,
        }) async => calls.add((key, discover, reason)),
      );
      addTearDown(coordinator.dispose);
      await coordinator.sync(only: {SyncKind.bitcoin});
      await coordinator.sync(only: {SyncKind.bitcoin});
      expect(calls, [(mainnet, true, SyncReason.auto)]);
      now = now.add(const Duration(seconds: 3));
      await coordinator.sync(only: {SyncKind.bitcoin});
      expect(calls.last, (mainnet, false, SyncReason.auto));
      await coordinator.sync(
        only: {SyncKind.bitcoin},
        trigger: SyncTrigger.user,
      );
      expect(calls.last, (mainnet, true, SyncReason.pull));
      environment = NetworkEnv.testnet;
      now = now.add(const Duration(seconds: 3));
      await coordinator.sync(only: {SyncKind.bitcoin});
      expect(calls.last, (testnet, true, SyncReason.auto));
      expect(calls, hasLength(4));
    },
  );
}

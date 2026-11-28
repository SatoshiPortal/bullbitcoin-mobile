import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('regtest admits liquid and swaps but not silent payments', () async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var environment = NetworkEnv.regtest;
    var liquidReads = 0;
    var swaps = 0;
    var silent = 0;
    final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
      walletKey: (key) => key,
      classifyFailure: (failure) =>
          (empty: failure is SyncNotFoundFailure, code: failure.logCode),
      readNetwork: () async => environment,
      getWallets: ({onlyBitcoin, onlyLiquid}) async {
        if (onlyLiquid == true) liquidReads++;
        return Ok(WalletRead([]));
      },
      syncWallet: (
        _, {
        discover = false,
        allowInitialScan = true,
        reason = SyncReason.auto,
      }) async {},
      syncSwaps: () async => swaps++,
      syncSp: () async => silent++,
    );
    addTearDown(coordinator.dispose);
    await coordinator.sync(
      only: {SyncKind.liquid, SyncKind.swaps, SyncKind.sp},
      trigger: SyncTrigger.user,
    );
    expect(liquidReads, 1);
    expect(swaps, 1);
    expect(silent, 0);
    environment = NetworkEnv.testnet;
    await coordinator.sync(only: {SyncKind.sp}, trigger: SyncTrigger.user);
    expect(silent, 1);
    environment = NetworkEnv.mainnet;
    await coordinator.sync(only: {SyncKind.sp}, trigger: SyncTrigger.user);
    expect(silent, 2);
  });

  test('paused app gates swap work but still refreshes revisions', () async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var swaps = 0;
    var revisions = 0;
    final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
      walletKey: (key) => key,
      classifyFailure: (failure) =>
          (empty: failure is SyncNotFoundFailure, code: failure.logCode),
      getWallets: ({onlyBitcoin, onlyLiquid}) async => Ok(WalletRead([])),
      syncWallet: (
        _, {
        discover = false,
        allowInitialScan = true,
        reason = SyncReason.auto,
      }) async {},
      syncSwaps: () async => swaps++,
      refreshRevisions: () async => revisions++,
    );
    addTearDown(() {
      coordinator.dispose();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await coordinator.sync(only: {SyncKind.swaps});
    expect(swaps, 0);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(revisions, 1);
  });
}

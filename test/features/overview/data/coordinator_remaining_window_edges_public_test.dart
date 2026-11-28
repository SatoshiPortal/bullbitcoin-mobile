import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final repeatedPull in [false, true]) {
    test('discovery window with repeatedPull=$repeatedPull', () async {
      final key = WalletKey(id: 'wallet', network: BitcoinNetwork.mainnet);
      var clock = DateTime.utc(2026);
      final calls = <(bool, SyncReason)>[];
      final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
        walletKey: (wallet) => wallet,
        classifyFailure: (failure) =>
            (empty: failure is SyncNotFoundFailure, code: failure.logCode),
        now: () => clock,
        getWallets: ({onlyBitcoin, onlyLiquid}) async => Ok(WalletRead([key])),
        syncWallet:
            (
              wallet, {
              discover = false,
              allowInitialScan = true,
              reason = SyncReason.auto,
            }) async {
              calls.add((discover, reason));
            },
      );
      addTearDown(coordinator.dispose);
      if (repeatedPull) {
        await coordinator.sync(
          only: {SyncKind.bitcoin},
          trigger: SyncTrigger.user,
        );
        await coordinator.sync(
          only: {SyncKind.bitcoin},
          trigger: SyncTrigger.user,
        );
        expect(calls, [(true, SyncReason.pull), (true, SyncReason.pull)]);
      } else {
        await coordinator.sync(only: {SyncKind.bitcoin});
        clock = clock.add(const Duration(seconds: 3));
        await coordinator.sync(only: {SyncKind.bitcoin});
        clock = clock.add(const Duration(minutes: 9));
        await coordinator.sync(only: {SyncKind.bitcoin});
        clock = clock.add(const Duration(minutes: 1));
        await coordinator.sync(only: {SyncKind.bitcoin});
        expect(calls, [
          (true, SyncReason.auto),
          (false, SyncReason.auto),
          (false, SyncReason.auto),
          (true, SyncReason.auto),
        ]);
      }
    });
  }
}

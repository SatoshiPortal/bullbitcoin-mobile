import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'failed discovery holds the window while pull and expiry retry',
    () async {
      final key = WalletKey(id: 'wallet', network: BitcoinNetwork.mainnet);
      var now = DateTime.utc(2026);
      var fail = true;
      final calls = <(bool, SyncReason)>[];
      final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
        walletKey: (wallet) => wallet,
        classifyFailure: (failure) =>
            (empty: failure is SyncNotFoundFailure, code: failure.logCode),
        now: () => now,
        getWallets: ({onlyBitcoin, onlyLiquid}) async => Ok(WalletRead([key])),
        syncWallet:
            (
              wallet, {
              discover = false,
              allowInitialScan = true,
              reason = SyncReason.auto,
            }) async {
              calls.add((discover, reason));
              if (fail) {
                throw const WalletSnapshotException(SyncConnectionFailure());
              }
            },
      );
      addTearDown(coordinator.dispose);
      await expectLater(
        coordinator.sync(only: {SyncKind.bitcoin}),
        throwsA(isA<SyncCoordinatorException>()),
      );
      fail = false;
      await coordinator.sync(only: {SyncKind.bitcoin});
      expect(calls, [(true, SyncReason.auto), (false, SyncReason.auto)]);
      await coordinator.sync(
        only: {SyncKind.bitcoin},
        trigger: SyncTrigger.user,
      );
      expect(calls.last, (true, SyncReason.pull));
      now = now.add(const Duration(minutes: 10));
      await coordinator.sync(only: {SyncKind.bitcoin});
      expect(calls.last, (true, SyncReason.auto));
      expect(calls, hasLength(4));
    },
  );
}

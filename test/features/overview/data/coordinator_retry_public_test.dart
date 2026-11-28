import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'busy manual and routine passes fail without throttling retry',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'overview-retry-',
      );
      final previous = log;
      log = Logger.replace(directory: directory);
      addTearDown(() async {
        await log.flush();
        log = previous;
        await directory.delete(recursive: true);
      });
      final key = WalletKey(id: 'private-id', network: BitcoinNetwork.mainnet);
      var busy = true;
      var calls = 0;
      final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
        walletKey: (wallet) => wallet,
        classifyFailure: (failure) =>
            (empty: failure is SyncNotFoundFailure, code: failure.logCode),
        getWallets: ({onlyBitcoin, onlyLiquid}) async => Ok(WalletRead([key])),
        syncWallet:
            (
              wallet, {
              discover = false,
              allowInitialScan = true,
              reason = SyncReason.auto,
            }) async {
              calls++;
              if (busy) {
                throw const WalletSnapshotException(SyncBusyFailure());
              }
            },
      );
      addTearDown(coordinator.dispose);
      expect(
        await coordinator.discoverWallet(key.id),
        isA<Err<void, WalletDiscoveryFailure>>(),
      );
      await expectLater(
        coordinator.sync(only: {SyncKind.bitcoin}),
        throwsA(isA<SyncCoordinatorException>()),
      );
      final failed = (await log.readLogs()).join();
      expect(failed, contains('discovery finished reason=manual outcome=busy'));
      expect(failed, contains('outcome=busy wallets=1 category=busy'));
      expect(failed, isNot(contains('outcome=settled')));
      expect(failed, isNot(contains(key.id)));
      busy = false;
      await coordinator.sync(only: {SyncKind.bitcoin});
      expect(calls, 3);
    },
  );

  test('manual Liquid does not discover or throttle a normal pass', () async {
    final key = WalletKey(id: 'liquid', network: LiquidNetwork.mainnet);
    final calls = <(bool, SyncReason)>[];
    final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
      walletKey: (wallet) => wallet,
      classifyFailure: (failure) =>
          (empty: failure is SyncNotFoundFailure, code: failure.logCode),
      getWallets: ({onlyBitcoin, onlyLiquid}) async => Ok(WalletRead([key])),
      syncWallet: (
        wallet, {
        discover = false,
        allowInitialScan = true,
        reason = SyncReason.auto,
      }) async => calls.add((discover, reason)),
    );
    addTearDown(coordinator.dispose);
    expect(
      await coordinator.discoverWallet(key.id),
      isA<Ok<void, WalletDiscoveryFailure>>(),
    );
    await coordinator.sync(only: {SyncKind.liquid});
    expect(calls, [(false, SyncReason.manual), (false, SyncReason.auto)]);
  });
}

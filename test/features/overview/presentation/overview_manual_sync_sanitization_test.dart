import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:primitives/primitives.dart';
import 'package:silent/silent.dart';
import 'package:sync/sync.dart';

import '../support/overview_home_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'manual sync reports stale balances without leaking its cause',
    () async {
      final directory = await Directory.systemTemp.createTemp('home-sync-log-');
      final previous = log;
      log = Logger.replace(directory: directory);
      final h = OverviewHomeHarness();
      final key = WalletKey(id: 'btc', network: BitcoinNetwork.mainnet);
      var attempts = 0;
      final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
        walletKey: (wallet) => wallet,
        classifyFailure: (failure) => (empty: false, code: failure.logCode),
        getWallets: ({onlyBitcoin, onlyLiquid}) async => Ok(
          WalletRead<WalletKey, SyncFailure>(onlyBitcoin == true ? [key] : []),
        ),
        syncWallet:
            (
              wallet, {
              discover = false,
              allowInitialScan = true,
              reason = SyncReason.auto,
            }) async {
              attempts++;
              throw Exception('private-sync-cause');
            },
      );
      final home = OverviewHomeController(
        catalogue: h.source,
        sync: CoordinatedHomeSync(coordinator),
        amountDisplay: OverviewAmountDisplay(h.amountPreferences),
        ongoingSwaps: h.swaps,
        swapServerCheck: h.swapServer,
        readBackupWarning: () async => null,
        readPhysicalBackup: (_) async => false,
        proxyNeedsAttention: () async => false,
        silentHome: SilentHomeObservation(h.silent),
        syncStarted: h.started.stream,
        syncFinished: h.finished.stream,
        electrumResults: h.electrum.stream,
      );
      addTearDown(() async {
        try {
          await log.flush();
        } finally {
          log = previous;
          await directory.delete(recursive: true);
        }
      });
      addTearDown(() async {
        await home.close();
        coordinator.dispose();
        await h.close();
      });

      h.source.publish(
        snapshot(OverviewCatalogueStatus.ready, [
          homeWallet('btc', network: BitcoinNetwork.mainnet, balanceSat: 100),
        ]),
      );
      await flushEvents();
      await home.refresh();
      expect(attempts, 1);
      expect(home.current.isRefreshing, isFalse);
      expect(home.current.loadFailure, OverviewLoadFailure.balancesMayBeStale);
      expect(home.current.rows.single.balanceSat, 100);
      final messages = await log.readLogs();
      expect(
        messages.where((line) => line.contains('private-sync-cause')),
        isEmpty,
      );
      final summaries = messages
          .where((line) => line.contains('Sync pass finished kind=bitcoin'))
          .toList();
      expect(summaries, hasLength(1));
      expect(summaries.single, contains('outcome=failed'));
      expect(summaries.single, contains('category=operation'));
    },
  );
}

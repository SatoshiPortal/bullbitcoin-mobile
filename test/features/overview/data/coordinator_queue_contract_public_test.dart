import 'dart:async';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('coalesced calls persist one pass and throttling is silent', () async {
    final directory = await Directory.systemTemp.createTemp('overview-queue-');
    final previous = log;
    log = Logger.replace(directory: directory);
    addTearDown(() async {
      await log.flush();
      log = previous;
      await directory.delete(recursive: true);
    });
    final gate = Completer<void>();
    final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
      walletKey: (key) => key,
      classifyFailure: (failure) =>
          (empty: failure is SyncNotFoundFailure, code: failure.logCode),
      getWallets: ({onlyBitcoin, onlyLiquid}) async {
        await gate.future;
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
    final first = coordinator.sync(only: {SyncKind.bitcoin});
    final second = coordinator.sync(only: {SyncKind.bitcoin});
    await pumpEventQueue();
    gate.complete();
    await Future.wait([first, second]);
    await coordinator.sync(only: {SyncKind.bitcoin});
    final rows = await log.readLogs();
    final passes = rows.where((row) => row.contains('Sync pass finished'));
    expect(passes, hasLength(1));
    expect(passes.single, contains('outcome=no_wallets wallets=0'));
    expect(rows.join(), isNot(contains('sync ok')));
  });

  test(
    'silent failure settles other kinds and is keyed in the aggregate',
    () async {
      var bitcoin = 0;
      var liquid = 0;
      var silent = 0;
      final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
        walletKey: (key) => key,
        classifyFailure: (failure) =>
            (empty: failure is SyncNotFoundFailure, code: failure.logCode),
        getWallets: ({onlyBitcoin, onlyLiquid}) async {
          if (onlyBitcoin == true) bitcoin++;
          if (onlyLiquid == true) liquid++;
          return Ok(WalletRead([]));
        },
        syncWallet: (
          _, {
          discover = false,
          allowInitialScan = true,
          reason = SyncReason.auto,
        }) async {},
        syncSp: () async {
          silent++;
          throw Exception('silent backend detail');
        },
      );
      addTearDown(coordinator.dispose);
      try {
        await coordinator.sync(
          only: {SyncKind.bitcoin, SyncKind.liquid, SyncKind.sp},
        );
        fail('expected an aggregate failure');
      } on SyncCoordinatorException catch (error) {
        expect(error.failures.keys, [SyncKind.sp]);
      }
      expect(bitcoin, 1);
      expect(liquid, 1);
      expect(silent, 1);
    },
  );
}

import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

final class _Reporter implements LoggerReporter {
  final errors = <Object>[];
  @override
  void reportError({
    String? message,
    required Object exception,
    required StackTrace stackTrace,
    required ReportCategory category,
  }) => errors.add(exception);
  @override
  Future<void> reportShout({
    required String message,
    Object? exception,
    StackTrace? stackTrace,
    ReportCategory? category,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'targeted polling and connection failures keep safe categorized logs',
    () async {
      final directory = await Directory.systemTemp.createTemp('overview-poll-');
      final previous = log;
      final reporter = _Reporter();
      log = Logger.replace(directory: directory, reporter: reporter);
      addTearDown(() async {
        await log.flush();
        log = previous;
        await directory.delete(recursive: true);
      });
      final key = WalletKey(
        id: 'private-wallet-id',
        network: BitcoinNetwork.mainnet,
      );
      var failure = 0;
      final calls = <(bool, bool, SyncReason)>[];
      final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
        walletKey: (wallet) => wallet,
        classifyFailure: (failure) =>
            (empty: failure is SyncNotFoundFailure, code: failure.logCode),
        readWallet: (_) async => Ok(key),
        getWallets: ({onlyBitcoin, onlyLiquid}) async => Ok(WalletRead([key])),
        syncWallet:
            (
              wallet, {
              discover = false,
              allowInitialScan = true,
              reason = SyncReason.auto,
            }) async {
              calls.add((discover, allowInitialScan, reason));
              if (failure == 1) {
                throw const WalletSnapshotException(SyncBusyFailure());
              }
              if (failure == 2) {
                throw const WalletSnapshotException(SyncConnectionFailure());
              }
            },
      );
      addTearDown(coordinator.dispose);
      await coordinator.sync(only: {SyncKind.bitcoin});
      await coordinator.pollWallet(key.id, isActive: () => true);
      await coordinator.pollWallet(key.id, isActive: () => true);
      failure = 1;
      await coordinator.pollWallet(key.id, isActive: () => true);
      failure = 2;
      await expectLater(
        coordinator.sync(only: {SyncKind.bitcoin}, trigger: SyncTrigger.user),
        throwsA(isA<SyncCoordinatorException>()),
      );
      expect(calls, [
        (true, true, SyncReason.auto),
        (false, false, SyncReason.auto),
        (false, false, SyncReason.auto),
        (false, false, SyncReason.auto),
        (true, true, SyncReason.pull),
      ]);
      final rows = (await log.readLogs()).join();
      expect(
        rows,
        contains('reason=auto outcome=settled wallets=1 category=none'),
      );
      expect(
        rows,
        contains('reason=auto outcome=busy wallets=1 category=busy'),
      );
      expect(
        rows,
        contains('reason=pull outcome=failed wallets=1 category=connection'),
      );
      expect(rows, isNot(contains(key.id)));
      expect(rows, isNot(contains('discovery')));
      expect(reporter.errors, isEmpty);
    },
  );
}

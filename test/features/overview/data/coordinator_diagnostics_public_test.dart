import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

final class _Reporter implements LoggerReporter {
  final errors = <String?>[];

  @override
  void reportError({
    String? message,
    required Object exception,
    required StackTrace stackTrace,
    required ReportCategory category,
  }) => errors.add(message);

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
    'mixed kinds preserve failure categories without disclosing causes',
    () async {
      final directory = await Directory.systemTemp.createTemp('overview-diag-');
      final previous = log;
      final reporter = _Reporter();
      log = Logger.replace(directory: directory, reporter: reporter);
      addTearDown(() async {
        await log.flush();
        log = previous;
        await directory.delete(recursive: true);
      });
      final bitcoin = WalletKey(
        id: 'private-wallet-bitcoin',
        network: BitcoinNetwork.mainnet,
      );
      final liquid = WalletKey(
        id: 'private-wallet-liquid',
        network: LiquidNetwork.mainnet,
      );
      final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
        walletKey: (key) => key,
        classifyFailure: (failure) =>
            (empty: failure is SyncNotFoundFailure, code: failure.logCode),
        getWallets: ({onlyBitcoin, onlyLiquid}) async =>
            Ok(WalletRead([onlyBitcoin == true ? bitcoin : liquid])),
        syncWallet:
            (
              key, {
              discover = false,
              allowInitialScan = true,
              reason = SyncReason.auto,
            }) async {
              if (key == bitcoin) {
                throw const WalletSnapshotException(SyncBusyFailure());
              }
              throw Exception('electrum.example.com private-certificate');
            },
      );
      addTearDown(coordinator.dispose);

      try {
        await coordinator.sync(only: {SyncKind.bitcoin, SyncKind.liquid});
        fail('expected aggregate failure');
      } on SyncCoordinatorException catch (error) {
        expect(
          error.failures.keys,
          unorderedEquals([SyncKind.bitcoin, SyncKind.liquid]),
        );
        final busy = error.failures[SyncKind.bitcoin];
        expect(busy, isA<WalletSnapshotException>());
        expect(
          (busy as WalletSnapshotException).failure,
          isA<SyncBusyFailure>(),
        );
        expect(error.failures[SyncKind.liquid], isA<Exception>());
      }
      final rows = (await log.readLogs())
          .where((row) => row.contains('Sync pass finished'))
          .toList();
      expect(rows, hasLength(2));
      expect(rows[0], contains('kind=bitcoin'));
      expect(rows[0], contains('outcome=busy wallets=1 category=busy'));
      expect(rows[1], contains('kind=liquid'));
      expect(rows[1], contains('outcome=failed wallets=1 category=operation'));
      for (final row in rows) {
        expect(row, isNot(contains(bitcoin.id)));
        expect(row, isNot(contains(liquid.id)));
        expect(row, isNot(contains('electrum.example.com')));
        expect(row, isNot(contains('private-certificate')));
      }
      expect(reporter.errors, isEmpty);
    },
  );
}

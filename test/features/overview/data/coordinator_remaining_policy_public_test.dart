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
    'all automatic kinds throttle while pull bypasses both chains',
    () async {
      var bitcoin = 0;
      var liquid = 0;
      var silent = 0;
      var swaps = 0;
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
        syncSp: () async => silent++,
        syncSwaps: () async => swaps++,
      );
      addTearDown(coordinator.dispose);
      await coordinator.sync();
      await coordinator.sync();
      expect((bitcoin, liquid, silent, swaps), (1, 1, 1, 0));
      await coordinator.sync(trigger: SyncTrigger.user);
      expect((bitcoin, liquid, silent, swaps), (2, 2, 1, 0));
    },
  );

  test('regtest unsupported SP logs once without warning or report', () async {
    final directory = await Directory.systemTemp.createTemp(
      'overview-regtest-',
    );
    final previous = log;
    final reporter = _Reporter();
    log = Logger.replace(directory: directory, reporter: reporter);
    addTearDown(() async {
      await log.flush();
      log = previous;
      await directory.delete(recursive: true);
    });
    var sp = 0;
    final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
      walletKey: (key) => key,
      classifyFailure: (failure) =>
          (empty: failure is SyncNotFoundFailure, code: failure.logCode),
      readNetwork: () async => NetworkEnv.regtest,
      getWallets: ({onlyBitcoin, onlyLiquid}) async => Ok(WalletRead([])),
      syncWallet: (
        _, {
        discover = false,
        allowInitialScan = true,
        reason = SyncReason.auto,
      }) async {},
      syncSp: () async => sp++,
    );
    addTearDown(coordinator.dispose);
    await coordinator.sync(only: {SyncKind.sp});
    await coordinator.sync(only: {SyncKind.sp});
    final rows = await log.readLogs();
    expect(rows.where((row) => row.contains('kind=sp')), hasLength(1));
    expect(rows.join(), isNot(contains('WARNING')));
    expect(reporter.errors, isEmpty);
    expect(sp, 0);
  });
}

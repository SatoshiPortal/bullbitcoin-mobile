import 'dart:async';
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
    'throttled no-op emits no activity or persisted pass and no report',
    () async {
      final directory = await Directory.systemTemp.createTemp('overview-noop-');
      final previous = log;
      final reporter = _Reporter();
      log = Logger.replace(directory: directory, reporter: reporter);
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
      final activity = <bool>[];
      final subscription = coordinator.syncPassActivity.listen(activity.add);
      addTearDown(subscription.cancel);
      final first = coordinator.sync(only: {SyncKind.bitcoin});
      final joined = coordinator.sync(only: {SyncKind.bitcoin});
      await pumpEventQueue();
      expect(activity, [true]);
      gate.complete();
      await Future.wait([first, joined]);
      await pumpEventQueue();
      expect(activity, [true, false]);
      final before = (await log.readLogs())
          .where((line) => line.contains('Sync pass finished'))
          .toList();
      expect(before, hasLength(1));
      expect(before.single, contains('kind=bitcoin reason=auto'));
      expect(
        before.single,
        contains('outcome=no_wallets wallets=0 category=none'),
      );
      activity.clear();
      await coordinator.sync(only: {SyncKind.bitcoin});
      await pumpEventQueue();
      expect(activity, isEmpty);
      expect(
        (await log.readLogs()).where(
          (line) => line.contains('Sync pass finished'),
        ),
        hasLength(1),
      );
      expect(reporter.errors, isEmpty);
    },
  );
}

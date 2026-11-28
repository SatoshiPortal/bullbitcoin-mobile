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

  for (final failure in [
    const SyncNotFoundFailure(),
    const SyncStorageFailure(),
  ]) {
    test(
      'both chain read failures ${failure.runtimeType} are not reported',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'overview-exact-',
        );
        final previous = log;
        final reporter = _Reporter();
        log = Logger.replace(directory: directory, reporter: reporter);
        addTearDown(() async {
          await log.flush();
          log = previous;
          await directory.delete(recursive: true);
        });
        final reads = <String>[];
        final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
          walletKey: (key) => key,
          classifyFailure: (failure) =>
              (empty: failure is SyncNotFoundFailure, code: failure.logCode),
          getWallets: ({onlyBitcoin, onlyLiquid}) async {
            reads.add(onlyBitcoin == true ? 'bitcoin' : 'liquid');
            return Err(failure);
          },
          syncWallet: (
            _, {
            discover = false,
            allowInitialScan = true,
            reason = SyncReason.auto,
          }) async {},
        );
        addTearDown(coordinator.dispose);
        try {
          await coordinator.sync(trigger: SyncTrigger.user);
          fail('expected both kinds to fail');
        } on SyncCoordinatorException catch (error) {
          expect(
            error.failures.keys,
            unorderedEquals([SyncKind.bitcoin, SyncKind.liquid]),
          );
          expect(error.failures.values, everyElement(same(failure)));
        }
        expect(reads, ['bitcoin', 'liquid']);
        expect(reporter.errors, isEmpty);
      },
    );
  }

  test('targeted Receive polls do not synchronize another wallet', () async {
    final a = WalletKey(id: 'a', network: BitcoinNetwork.mainnet);
    final b = WalletKey(id: 'b', network: BitcoinNetwork.mainnet);
    final calls = <(WalletKey, bool, bool, SyncReason)>[];
    final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
      walletKey: (wallet) => wallet,
      classifyFailure: (failure) =>
          (empty: failure is SyncNotFoundFailure, code: failure.logCode),
      readWallet: (id) async => Ok(id == 'a' ? a : b),
      getWallets: ({onlyBitcoin, onlyLiquid}) async => Ok(WalletRead([a])),
      syncWallet: (
        wallet, {
        discover = false,
        allowInitialScan = true,
        reason = SyncReason.auto,
      }) async => calls.add((wallet, discover, allowInitialScan, reason)),
    );
    addTearDown(coordinator.dispose);
    await coordinator.sync(only: {SyncKind.bitcoin});
    await coordinator.pollWallet(a.id, isActive: () => true);
    await coordinator.pollWallet(a.id, isActive: () => true);
    expect(calls, [
      (a, true, true, SyncReason.auto),
      (a, false, false, SyncReason.auto),
      (a, false, false, SyncReason.auto),
    ]);
    expect(calls.where((call) => call.$1 == b), isEmpty);
  });
}

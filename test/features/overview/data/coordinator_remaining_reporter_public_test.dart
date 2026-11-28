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
  late Directory directory;
  late Logger previous;
  late _Reporter reporter;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('overview-report-');
    previous = log;
    reporter = _Reporter();
    log = Logger.replace(directory: directory, reporter: reporter);
  });
  tearDown(() async {
    await log.flush();
    log = previous;
    await directory.delete(recursive: true);
  });

  for (final failure in [
    const SyncNotFoundFailure(),
    const SyncStorageFailure(),
  ]) {
    test(
      'joined ${failure.runtimeType} read failures are not reported',
      () async {
        final gate = Completer<void>();
        var reads = 0;
        final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
          walletKey: (key) => key,
          classifyFailure: (failure) =>
              (empty: failure is SyncNotFoundFailure, code: failure.logCode),
          getWallets: ({onlyBitcoin, onlyLiquid}) async {
            reads++;
            await gate.future;
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
        final first = coordinator.sync(
          only: {SyncKind.bitcoin},
          trigger: SyncTrigger.user,
        );
        final second = coordinator.sync(
          only: {SyncKind.bitcoin},
          trigger: SyncTrigger.user,
        );
        final firstCheck = expectLater(
          first,
          throwsA(isA<SyncCoordinatorException>()),
        );
        final secondCheck = expectLater(
          second,
          throwsA(isA<SyncCoordinatorException>()),
        );
        await pumpEventQueue();
        gate.complete();
        await Future.wait([firstCheck, secondCheck]);
        expect(reads, 1);
        expect(reporter.errors, isEmpty);
        final rows = (await log.readLogs())
            .where((row) => row.contains('Sync pass finished'))
            .toList();
        expect(rows, hasLength(1));
        expect(
          rows.single,
          contains(
            failure is SyncNotFoundFailure
                ? 'category=not_found'
                : 'category=storage',
          ),
        );
      },
    );
  }

  test(
    'queued pull upgrades Liquid but running Bitcoin retains auto',
    () async {
      final bitcoin = WalletKey(
        id: 'private-btc',
        network: BitcoinNetwork.mainnet,
      );
      final liquid = WalletKey(
        id: 'private-liquid',
        network: LiquidNetwork.mainnet,
      );
      final gate = Completer<void>();
      final calls = <(WalletKey, bool, SyncReason)>[];
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
              calls.add((key, discover, reason));
              if (key == bitcoin) {
                await gate.future;
              }
            },
      );
      addTearDown(coordinator.dispose);
      final auto = coordinator.sync(only: {SyncKind.bitcoin, SyncKind.liquid});
      await pumpEventQueue();
      final pull = coordinator.sync(
        only: {SyncKind.bitcoin, SyncKind.liquid},
        trigger: SyncTrigger.user,
      );
      await pumpEventQueue();
      gate.complete();
      await Future.wait([auto, pull]);
      expect(calls, [
        (bitcoin, true, SyncReason.auto),
        (liquid, false, SyncReason.pull),
      ]);
      final rows = (await log.readLogs())
          .where((row) => row.contains('Sync pass finished'))
          .toList();
      expect(rows, hasLength(2));
      expect(rows[0], contains('kind=bitcoin reason=auto'));
      expect(rows[1], contains('kind=liquid reason=pull'));
      expect(rows, everyElement(contains('category=none')));
      expect(rows.join(), isNot(contains(bitcoin.id)));
      expect(rows.join(), isNot(contains(liquid.id)));
      expect(reporter.errors, isEmpty);
    },
  );
}

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

  for (final failRoutine in [false, true]) {
    test('manual discovery survives routine failure=$failRoutine', () async {
      final key = WalletKey(
        id: 'private-wallet-id',
        network: BitcoinNetwork.mainnet,
      );
      final other = WalletKey(id: 'other', network: BitcoinNetwork.mainnet);
      final routineGate = Completer<void>();
      final manualGate = Completer<void>();
      final calls = <(WalletKey, bool, SyncReason)>[];
      final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
        walletKey: (wallet) => wallet,
        classifyFailure: (failure) =>
            (empty: failure is SyncNotFoundFailure, code: failure.logCode),
        getWallets: ({onlyBitcoin, onlyLiquid}) async =>
            Ok(WalletRead(onlyBitcoin == true ? [key] : [key, other])),
        syncWallet:
            (
              wallet, {
              discover = false,
              allowInitialScan = true,
              reason = SyncReason.auto,
            }) async {
              calls.add((wallet, discover, reason));
              if (reason == SyncReason.auto) {
                await routineGate.future;
                if (failRoutine) throw Exception('routine');
              } else {
                await manualGate.future;
              }
            },
      );
      addTearDown(coordinator.dispose);
      final activity = <bool>[];
      final subscription = coordinator.syncPassActivity.listen(activity.add);
      addTearDown(subscription.cancel);
      final routine = coordinator.sync(only: {SyncKind.bitcoin});
      final settled = failRoutine
          ? expectLater(routine, throwsA(isA<SyncCoordinatorException>()))
          : routine;
      await pumpEventQueue();
      final first = coordinator.discoverWallet(key.id);
      final second = coordinator.discoverWallet(key.id);
      await pumpEventQueue();
      expect(calls, [(key, true, SyncReason.auto)]);
      routineGate.complete();
      await settled;
      await pumpEventQueue();
      expect(activity, [true]);
      expect(coordinator.isSyncPassActive, isTrue);
      expect(calls, [
        (key, true, SyncReason.auto),
        (key, true, SyncReason.manual),
      ]);
      manualGate.complete();
      expect(await first, isA<Ok<void, WalletDiscoveryFailure>>());
      expect(await second, isA<Ok<void, WalletDiscoveryFailure>>());
      await pumpEventQueue();
      expect(activity, [true, false]);
      expect(coordinator.isSyncPassActive, isFalse);
      expect(calls, hasLength(2));
    });
  }

  test(
    'manual discovery sanitizes failure and logs only one start and finish',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'overview-manual-',
      );
      final previous = log;
      log = Logger.replace(directory: directory);
      addTearDown(() async {
        await log.flush();
        log = previous;
        await directory.delete(recursive: true);
      });
      final key = WalletKey(
        id: 'private-wallet-id',
        network: BitcoinNetwork.mainnet,
      );
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
        }) async => throw Exception('electrum.example.com private-certificate'),
      );
      addTearDown(coordinator.dispose);

      expect(
        await coordinator.discoverWallet(key.id),
        isA<Err<void, WalletDiscoveryFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<WalletDiscoverySyncFailure>(),
        ),
      );
      final rows = await log.readLogs();
      expect(
        rows.where((row) => row.contains('discovery started reason=manual')),
        hasLength(1),
      );
      expect(
        rows.where(
          (row) =>
              row.contains('discovery finished reason=manual outcome=failed'),
        ),
        hasLength(1),
      );
      expect(rows.join(), isNot(contains(key.id)));
      expect(rows.join(), isNot(contains('electrum.example.com')));
      expect(rows.join(), isNot(contains('private-certificate')));
    },
  );
}

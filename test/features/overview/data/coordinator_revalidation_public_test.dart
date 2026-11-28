import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'queued manual discovery refuses a wallet removed during a pass',
    () async {
      final key = WalletKey(id: 'a', network: BitcoinNetwork.mainnet);
      final gate = Completer<void>();
      var wallets = [key];
      var synchronizations = 0;
      final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
        walletKey: (wallet) => wallet,
        classifyFailure: (failure) =>
            (empty: failure is SyncNotFoundFailure, code: failure.logCode),
        getWallets: ({onlyBitcoin, onlyLiquid}) async {
          if (onlyBitcoin == true) {
            await gate.future;
            return Ok(WalletRead([]));
          }
          return Ok(WalletRead(wallets));
        },
        syncWallet:
            (
              wallet, {
              discover = false,
              allowInitialScan = true,
              reason = SyncReason.auto,
            }) async {
              synchronizations++;
            },
      );
      addTearDown(coordinator.dispose);
      final running = coordinator.sync(only: {SyncKind.bitcoin});
      await pumpEventQueue();
      final manual = coordinator.discoverWallet(key.id);
      await pumpEventQueue();
      wallets = [];
      gate.complete();
      await running;
      expect(
        await manual,
        isA<Err<void, WalletDiscoveryFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<WalletDiscoveryUnavailableFailure>(),
        ),
      );
      expect(synchronizations, 0);
    },
  );

  test(
    'targeted polling joins a running pass then rejects another network',
    () async {
      final key = WalletKey(id: 'a', network: BitcoinNetwork.mainnet);
      final gate = Completer<void>();
      var environment = NetworkEnv.mainnet;
      var enumerations = 0;
      final calls = <(bool, bool, SyncReason)>[];
      final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
        walletKey: (wallet) => wallet,
        classifyFailure: (failure) =>
            (empty: failure is SyncNotFoundFailure, code: failure.logCode),
        readNetwork: () async => environment,
        readWallet: (_) async => Ok(key),
        getWallets: ({onlyBitcoin, onlyLiquid}) async {
          enumerations++;
          return Ok(WalletRead([key]));
        },
        syncWallet:
            (
              wallet, {
              discover = false,
              allowInitialScan = true,
              reason = SyncReason.auto,
            }) async {
              calls.add((discover, allowInitialScan, reason));
              await gate.future;
            },
      );
      addTearDown(coordinator.dispose);
      var active = true;
      final first = coordinator.pollWallet(key.id, isActive: () => active);
      await pumpEventQueue();
      active = false;
      var joinedFinished = false;
      final joined = coordinator
          .pollWallet(key.id, isActive: () => true)
          .then((_) => joinedFinished = true);
      await pumpEventQueue();
      expect(joinedFinished, isFalse);
      expect(calls, [(false, false, SyncReason.auto)]);
      gate.complete();
      await Future.wait([first, joined]);
      expect(joinedFinished, isTrue);
      environment = NetworkEnv.testnet;
      await coordinator.pollWallet(key.id, isActive: () => true);
      expect(calls, [(false, false, SyncReason.auto)]);
      expect(enumerations, 0);
    },
  );
}

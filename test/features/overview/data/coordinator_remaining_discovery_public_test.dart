import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final main = WalletKey(id: 'main', network: BitcoinNetwork.mainnet);
  final testnet = WalletKey(id: 'test', network: BitcoinNetwork.testnet);
  final liquid = WalletKey(id: 'liquid', network: LiquidNetwork.mainnet);
  late DateTime clock;
  late NetworkEnv environment;
  late List<(WalletKey, bool, SyncReason)> calls;
  late SyncCoordinator<WalletKey, SyncFailure> coordinator;
  Completer<void>? gate;
  var failDiscovery = false;

  setUp(() {
    clock = DateTime.utc(2026);
    environment = NetworkEnv.mainnet;
    calls = [];
    gate = null;
    failDiscovery = false;
    coordinator = SyncCoordinator<WalletKey, SyncFailure>(
      walletKey: (key) => key,
      classifyFailure: (failure) =>
          (empty: failure is SyncNotFoundFailure, code: failure.logCode),
      now: () => clock,
      readNetwork: () async => environment,
      getWallets: ({onlyBitcoin, onlyLiquid}) async => Ok(
        WalletRead([
          if (onlyLiquid == true)
            liquid
          else if (environment == NetworkEnv.mainnet)
            main
          else
            testnet,
        ]),
      ),
      syncWallet:
          (
            key, {
            discover = false,
            allowInitialScan = true,
            reason = SyncReason.auto,
          }) async {
            calls.add((key, discover, reason));
            if (!discover && gate != null) {
              await gate?.future;
            }
            if (discover && failDiscovery) {
              throw const WalletSnapshotException(SyncConnectionFailure());
            }
          },
    );
  });
  tearDown(() => coordinator.dispose());

  Future<void> bitcoin({SyncTrigger trigger = SyncTrigger.automatic}) =>
      coordinator.sync(only: {SyncKind.bitcoin}, trigger: trigger);

  test('pull queues discovery behind an in-flight routine', () async {
    await bitcoin();
    clock = clock.add(const Duration(seconds: 3));
    gate = Completer<void>();
    final routine = bitcoin();
    await pumpEventQueue();
    var finished = false;
    final pull = bitcoin(trigger: SyncTrigger.user)
        .then((_) => finished = true);
    await pumpEventQueue();
    expect(finished, isFalse);
    gate?.complete();
    await Future.wait([routine, pull]);
    expect(calls, [
      (main, true, SyncReason.auto),
      (main, false, SyncReason.auto),
      (main, true, SyncReason.pull),
    ]);
  });

  test('a throttled pass does not open the discovery window', () async {
    await bitcoin();
    clock = clock.add(const Duration(minutes: 9, seconds: 59));
    await bitcoin();
    clock = clock.add(const Duration(seconds: 1, milliseconds: 500));
    await bitcoin();
    clock = clock.add(const Duration(seconds: 3));
    await bitcoin();
    expect(calls, [
      (main, true, SyncReason.auto),
      (main, false, SyncReason.auto),
      (main, true, SyncReason.auto),
    ]);
  });

  test('repeated pulls retry discovery even after failure', () async {
    failDiscovery = true;
    await expectLater(bitcoin(), throwsA(isA<SyncCoordinatorException>()));
    clock = clock.add(const Duration(seconds: 3));
    await bitcoin();
    await expectLater(
      bitcoin(trigger: SyncTrigger.user),
      throwsA(isA<SyncCoordinatorException>()),
    );
    failDiscovery = false;
    await bitcoin(trigger: SyncTrigger.user);
    expect(calls, [
      (main, true, SyncReason.auto),
      (main, false, SyncReason.auto),
      (main, true, SyncReason.pull),
      (main, true, SyncReason.pull),
    ]);
  });

  test(
    'returning to an environment keeps its own window; Liquid never discovers',
    () async {
      environment = NetworkEnv.testnet;
      await bitcoin();
      environment = NetworkEnv.mainnet;
      clock = clock.add(const Duration(seconds: 3));
      await bitcoin();
      environment = NetworkEnv.testnet;
      clock = clock.add(const Duration(seconds: 3));
      await bitcoin();
      await coordinator.sync(only: {SyncKind.liquid});
      expect(calls, [
        (testnet, true, SyncReason.auto),
        (main, true, SyncReason.auto),
        (testnet, false, SyncReason.auto),
        (liquid, false, SyncReason.auto),
      ]);
    },
  );
}

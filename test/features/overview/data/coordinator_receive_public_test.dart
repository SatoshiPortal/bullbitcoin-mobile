import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:overview/overview.dart';
import 'package:overview/setup.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bitcoin = WalletKey(id: 'a', network: BitcoinNetwork.mainnet);
  final liquid = WalletKey(id: 'liquid', network: LiquidNetwork.mainnet);

  for (final cancellation in ['never', 'beforeJoin', 'afterJoin']) {
    test(
      'Receive joins covered work with cancellation=$cancellation',
      () async {
        final held = Completer<void>();
        final calls = <(WalletKey, bool, bool, SyncReason)>[];
        final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
          walletKey: (key) => key,
          classifyFailure: (failure) =>
              (empty: failure is SyncNotFoundFailure, code: failure.logCode),
          readNetwork: () async => NetworkEnv.mainnet,
          readWallet: (id) async => Ok(id == 'a' ? bitcoin : liquid),
          getWallets: ({onlyBitcoin, onlyLiquid}) async =>
              Ok(WalletRead([bitcoin])),
          syncWallet:
              (
                key, {
                discover = false,
                allowInitialScan = true,
                reason = SyncReason.auto,
              }) async {
                calls.add((key, discover, allowInitialScan, reason));
                if (key == bitcoin) await held.future;
              },
        );
        addTearDown(coordinator.dispose);
        final global = coordinator.sync(only: {SyncKind.bitcoin});
        await pumpEventQueue();
        var runningEnded = false;
        final running = coordinator
            .pollWallet('a', isActive: () => true)
            .then((_) => runningEnded = true);
        var active = true;
        final queued = coordinator.pollWallet('liquid', isActive: () => active);
        await pumpEventQueue();
        if (cancellation == 'beforeJoin') active = false;
        var joinedEnded = false;
        final joined = coordinator
            .pollWallet('liquid', isActive: () => true)
            .then((_) => joinedEnded = true);
        await pumpEventQueue();
        expect(runningEnded, isFalse);
        expect(joinedEnded, isFalse);
        expect(calls, [(bitcoin, true, true, SyncReason.auto)]);
        if (cancellation == 'afterJoin') active = false;
        held.complete();
        await Future.wait([global, queued, running, joined]);
        expect(runningEnded, isTrue);
        expect(joinedEnded, isTrue);
        expect(calls, [
          (bitcoin, true, true, SyncReason.auto),
          (liquid, false, false, SyncReason.auto),
        ]);
        await coordinator.pollWallet('liquid', isActive: () => true);
        expect(calls, [
          (bitcoin, true, true, SyncReason.auto),
          (liquid, false, false, SyncReason.auto),
          (liquid, false, false, SyncReason.auto),
        ]);
      },
    );
  }

  test('cancellation is rechecked after targeted inventory read', () async {
    final pending = Completer<Result<WalletKey, SyncFailure>>();
    var active = true;
    var enumerations = 0;
    var syncs = 0;
    final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
      walletKey: (key) => key,
      classifyFailure: (failure) =>
          (empty: failure is SyncNotFoundFailure, code: failure.logCode),
      readWallet: (_) => pending.future,
      getWallets: ({onlyBitcoin, onlyLiquid}) async {
        enumerations++;
        return Ok(WalletRead([bitcoin]));
      },
      syncWallet:
          (
            key, {
            discover = false,
            allowInitialScan = true,
            reason = SyncReason.auto,
          }) async {
            syncs++;
          },
    );
    addTearDown(coordinator.dispose);
    final poll = coordinator.pollWallet('a', isActive: () => active);
    active = false;
    pending.complete(Ok(bitcoin));
    await poll;
    expect(enumerations, 0);
    expect(syncs, 0);
  });

  test(
    'pull joins in-flight automatic discovery without repeating it',
    () async {
      final gate = Completer<void>();
      final calls = <(bool, SyncReason)>[];
      final coordinator = SyncCoordinator<WalletKey, SyncFailure>(
        walletKey: (key) => key,
        classifyFailure: (failure) =>
            (empty: failure is SyncNotFoundFailure, code: failure.logCode),
        getWallets: ({onlyBitcoin, onlyLiquid}) async =>
            Ok(WalletRead([bitcoin])),
        syncWallet:
            (
              key, {
              discover = false,
              allowInitialScan = true,
              reason = SyncReason.auto,
            }) async {
              calls.add((discover, reason));
              await gate.future;
            },
      );
      addTearDown(coordinator.dispose);
      final automatic = coordinator.sync(only: {SyncKind.bitcoin});
      await pumpEventQueue();
      var pullFinished = false;
      final pull = coordinator
          .sync(only: {SyncKind.bitcoin}, trigger: SyncTrigger.user)
          .then((_) => pullFinished = true);
      await pumpEventQueue();
      expect(pullFinished, isFalse);
      expect(calls, [(true, SyncReason.auto)]);
      gate.complete();
      await Future.wait([automatic, pull]);
      expect(pullFinished, isTrue);
      expect(calls, [(true, SyncReason.auto)]);
    },
  );
}

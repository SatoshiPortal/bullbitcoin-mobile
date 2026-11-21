import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart';
import 'package:test/test.dart';

import 'support/real_swap_backends.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final action in ['retry', 'stop']) {
    test(
      'R4 $action can report a bounded result while a chain request hangs',
      () async {
        final db = BoltzSwapsDatabase(NativeDatabase.memory());
        final storage = SwapStorage(
          rows: DriftSwapRowStore(db),
          secrets: ReproKeychainBackend().capability,
        );
        final entered = Completer<void>();
        final release = Completer<bool>();
        final chain = ReproChainBackend()
          ..lookup = () {
            if (!entered.isCompleted) entered.complete();
            return release.future;
          };
        final provider = BoltzSwapRepository.connect(
          url: 'http://127.0.0.1:1',
          storage: storage,
          environment: NetworkEnv.testnet,
          electrum: ReproElectrumBackend(),
          lockupChain: chain,
          newAddressFor: (_) async => throw StateError('No address needed'),
          walletTx: (_, {required walletId}) async => null,
          walletTxs: (_, {bool sync = false}) async => const [],
          fastestFee: ({
            required txSize,
            required isLiquid,
            required environment,
          }) async => 1,
          wallets: ({required environment}) async => const [],
          swapMasterKeySource: ({required environment}) async => null,
        );
        final watcher = SwapWatcher(
          store: SwapStoreImpl(
            storage: storage,
            environment: NetworkEnv.testnet,
          ),
          resolvers: {SwapProvider.boltz: provider},
        );
        final model = SwapModel.lnSend(
          id: 'R40000000002',
          type: SwapType.bitcoinToLightning.name,
          status: SwapStatus.pending.name,
          isTestnet: true,
          keyIndex: 0,
          creationTime: DateTime.now().millisecondsSinceEpoch,
          sendWalletId: 'test-wallet',
          paymentAddress: 'fixture-lockup-address',
          paymentAmount: 10000,
          invoice: 'unused-by-pending-lockup-resolution',
          pendingLockupTx: 'opaque-signed-transaction',
          pendingLockupTxid: 'a' * 64,
        );
        await storage.store(model);
        final running = watcher.processSwap(model.toEntity());
        await entered.future.timeout(const Duration(seconds: 3));
        final requested = action == 'retry'
            ? watcher.retry(model.toEntity()).then<void>((_) {})
            : watcher.stop();
        addTearDown(() async {
          if (!release.isCompleted) release.complete(true);
          await running;
          await requested;
          await watcher.stop();
          provider.dispose();
          await db.close();
        });

        final answered = await Future.any([
          requested.then((_) => true),
          Future<bool>.delayed(const Duration(milliseconds: 150), () => false),
        ]);
        expect(
          answered,
          isTrue,
          reason:
              '$action must be able to report busy/unavailable promptly; '
              'this assertion does not authorize abandoning the held action '
              'or admitting a second driver',
        );
        if (action == 'stop') {
          expect(await watcher.stop(), isA<Err<void, SwapsFailure>>());
          var drained = false;
          unawaited(watcher.drained.then((_) => drained = true));
          watcher.ensureRunning();
          await watcher.start();
          await watcher.processSwap(model.toEntity());
          expect(
            await watcher.retry(model.toEntity()),
            isA<Err<Swap, SwapsFailure>>(),
          );
          expect(watcher.isRunning, isFalse);
          expect(drained, isFalse);
          expect(chain.knownLookups, 1);
          release.complete(true);
          await watcher.drained;
          expect(drained, isTrue);
          final retained =
              (await storage.fetch(model.id))?.toEntity() as LnSendSwap?;
          expect(
            retained?.sendTxid,
            'a' * 64,
            reason: 'An admitted positive receipt survives suspension',
          );
          watcher.ensureRunning();
          expect(watcher.isRunning, isTrue);
        }
      },
    );
  }
}

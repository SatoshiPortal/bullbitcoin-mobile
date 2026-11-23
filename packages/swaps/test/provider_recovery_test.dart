import 'package:primitives/primitives.dart' show NetworkEnv;

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:swaps/swaps.dart';
import 'package:test/test.dart';

import 'support/real_swap_backends.dart';

void main() {
  SwapNetworkTestBinding();
  for (final holdResponse in [false, true]) {
    test('R4 ${holdResponse ? 'hung provider' : 'responsive provider control'} '
        'does not starve a locally known pending lockup', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requested = Completer<void>();
      final heldResponses = <HttpResponse>[];
      final sockets = <WebSocket>[];
      final requests = server.listen((request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          sockets.add(socket);
          socket.listen((_) {});
          return;
        }
        if (request.uri.path.contains('/swap/')) {
          if (!requested.isCompleted) requested.complete();
          if (holdResponse) {
            heldResponses.add(request.response);
          } else {
            request.response.headers.contentType = ContentType.json;
            request.response.write('{"status":"swap.created"}');
            await request.response.close();
          }
          return;
        }
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
      });
      final db = BoltzSwapsDatabase(NativeDatabase.memory());
      final storage = SwapStorage(
        rows: DriftSwapRowStore(db),
        secrets: ReproKeychainBackend().capability,
      );
      final chain = ReproChainBackend();
      final provider = BoltzSwapRepository.connect(
        url: 'http://127.0.0.1:${server.port}',
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
      final store = SwapStoreImpl(
        storage: storage,
        environment: NetworkEnv.testnet,
      );
      final watcher = SwapWatcher(
        store: store,
        resolvers: {SwapProvider.boltz: provider},
        heartbeat: const Duration(milliseconds: 20),
      );
      Future<void>? startup;
      addTearDown(() async {
        for (final response in heldResponses) {
          response.statusCode = HttpStatus.serviceUnavailable;
          await response.close();
        }
        await server.close(force: true);
        await requests.cancel();
        if (startup != null) await startup;
        await watcher.stop();
        provider.dispose();
        for (final socket in sockets) {
          await socket.close();
        }
        await db.close();
      });
      const id = 'R40000000001';
      await storage.store(
        SwapModel.lnSend(
          id: id,
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
        ),
      );

      startup = watcher.start();
      await requested.future.timeout(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // The backend never answers, but local recovery needs only the chain.
      final recorded = await storage.fetch(id) as LnSendSwapModel;
      expect(
        recorded.sendTxid,
        'a' * 64,
        reason:
            'Several heartbeats elapsed while the provider GET was held; '
            'a locally known lockup must still be settled',
      );
      expect(chain.knownLookups, greaterThan(0));
    });
  }
}

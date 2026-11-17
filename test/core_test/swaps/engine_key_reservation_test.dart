import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bb_mobile/core/swaps/switchable_swap_engine.dart';
import 'package:bull_sdk/bull_sdk.dart';
import 'package:bull_sdk/boltz.dart' as native;
import 'package:drift/native.dart';
import 'package:primitives/primitives.dart' show Err;
import 'package:swaps/swaps.dart';
import 'package:test/test.dart';

import 'support/real_swap_backends.dart';

// A controllable keychain backend holds the real counter reads. Nothing
// replaces either repository, reservation algorithm, store or native helper.
class _ReadBarrierKeychain extends ReproKeychainBackend {
  bool enabled = false;
  int counterReads = 0;
  final bothRead = Completer<void>();
  final firstRead = Completer<void>();

  @override
  Future<String?> read(String key) async {
    final snapshot = await super.read(key);
    if (enabled && key.startsWith('swap_master_key_index_')) {
      counterReads++;
      if (!firstRead.isCompleted) firstRead.complete();
      if (counterReads <= 2) {
        if (counterReads == 2) bothRead.complete();
        await bothRead.future.timeout(const Duration(seconds: 5));
      }
    }
    return snapshot;
  }
}

void main() {
  setUpAll(BullSdk.init);
  for (final replaceEngine in [false, true]) {
    test(
      'R6 ${replaceEngine ? 'real engine replacement' : 'sequential same-engine control'} reserves disjoint child-key ranges',
      () async {
        final random = Random.secure();
        // Ephemeral test-only material is never printed or written to disk.
        final key = await native.SwapMasterKey.createFromSeed(
          seed: List<int>.generate(64, (_) => random.nextInt(256)),
          network: native.Network.testnet,
        );
        final db = BoltzSwapsDatabase(NativeDatabase.memory());
        final keychain = _ReadBarrierKeychain();
        final storage = SwapStorage(
          rows: DriftSwapRowStore(db),
          secrets: keychain,
        );
        await storage.setSwapKeyIndex(key.fingerprint, 0);
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        var createRequests = 0;
        final pair = {
          'hash': '0' * 64,
          'rate': 1.0,
          'limits': {
            'minimal': 1000,
            'maximal': 1000000,
            'maximalZeroConf': 1000000,
          },
          'fees': {
            'percentage': 0.1,
            'minerFees': {
              'server': 100,
              'user': {'lockup': 100, 'claim': 100},
            },
          },
        };
        final listener = server.listen((request) async {
          request.response.headers.contentType = ContentType.json;
          if (request.method == 'GET' && request.uri.path == '/swap/chain') {
            request.response.write(
              jsonEncode({
                'BTC': {'L-BTC': pair},
                'L-BTC': {'BTC': pair},
              }),
            );
          } else {
            if (request.method == 'POST' && request.uri.path == '/swap/chain') {
              createRequests++;
              await request.drain<void>();
            }
            request.response.statusCode = HttpStatus.badRequest;
            request.response.write(
              '{"error":"controlled unfunded creation refusal"}',
            );
          }
          await request.response.close();
        });
        BoltzSwapRepository repository() => BoltzSwapRepository.connect(
          url: 'http://127.0.0.1:${server.port}',
          storage: storage,
          isTestnet: true,
          electrum: ReproElectrumBackend(),
          lockupChain: ReproChainBackend(),
          newAddressFor: (_) async =>
              'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx',
          walletTx: (_, {required walletId}) async => null,
          walletTxs: (_, {bool sync = false}) async => const [],
          fastestFee: ({
            required txSize,
            required isLiquid,
            required isTestnet,
          }) async => 1,
          wallets: ({required isTestnet}) async => const [
            SwapWalletInfo(
              id: 'btc',
              isLiquid: false,
              isDefault: true,
              fingerprint: 'test-root',
            ),
            SwapWalletInfo(
              id: 'liquid',
              isLiquid: true,
              isDefault: true,
              fingerprint: 'test-root',
            ),
          ],
          swapMasterKeySource: ({required isTestnet}) async =>
              throw StateError('The real stored key must be reused'),
        );
        final first = repository();
        await first.storeSwapMasterKey(
          DerivedSwapMasterKey(
            walletFingerprint: 'test-root',
            xprv: key.xprv,
            xpub: key.xpub,
            mnemonic: key.mnemonic,
            fingerprint: key.fingerprint,
            isTestnet: true,
          ),
        );
        final second = repository();
        addTearDown(() async {
          first.dispose();
          second.dispose();
          await server.close(force: true);
          await listener.cancel();
          await db.close();
        });
        final engine = SwitchableSwapEngine((
          store: SwapStoreImpl(storage: storage, isTestnet: true),
          boltz: first,
        ));
        keychain.enabled = replaceEngine;

        final oldCreation = engine.createLiquidToBitcoinSwap(
          sendWalletId: 'liquid',
          amountSat: 10000,
          destination: const ToWallet('btc'),
        );
        if (replaceEngine) {
          await keychain.firstRead.future.timeout(const Duration(seconds: 5));
          await engine.replace((
            store: SwapStoreImpl(storage: storage, isTestnet: true),
            boltz: second,
          ));
        } else {
          await oldCreation;
        }
        final newCreation = engine.createLiquidToBitcoinSwap(
          sendWalletId: 'liquid',
          amountSat: 10000,
          destination: const ToWallet('btc'),
        );
        final results = await Future.wait([oldCreation, newCreation])
            .timeout(const Duration(seconds: 15));

        // Rejecting creation is a network-backend fixture. Both real native
        // helpers must nevertheless be reached AFTER durable reservation.
        expect(results, everyElement(isA<Err<ChainSwap, SwapsFailure>>()));
        expect(
          createRequests,
          2,
          reason:
              'Both native creation paths must reach the controlled backend',
        );
        expect(
          await storage.getSwapKeyIndex(key.fingerprint),
          4,
          reason:
              'Two chain creations each consume two indices; the shared '
              'watermark must advance twice even when backend creation refuses',
        );
      },
    );
  }
}

import 'package:primitives/primitives.dart' show NetworkEnv;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bb_mobile/core/swaps/switchable_swap_engine.dart';
import 'package:rust_bindings/rust_bindings.dart';
import 'package:rust_bindings/boltz.dart' as native;
import 'package:drift/native.dart';
import 'package:primitives/primitives.dart' show Err, Ok;
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
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    final snapshot = await super.read(key: key, options: options);
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
  SwapNetworkTestBinding();
  setUpAll(BullSdk.init);
  for (final variant in [
    'same-engine',
    'same-network replacement',
    'testnet-regtest replacement',
  ]) {
    final replaceEngine = variant != 'same-engine';
    final crossEnvironment = variant == 'testnet-regtest replacement';
    test(
      'R6 real $variant with a shared fingerprint preserves disjoint child-key ranges',
      () async {
        final random = Random.secure();
        // Ephemeral test-only material is never printed or written to disk.
        final seed = List<int>.generate(64, (_) => random.nextInt(256));
        final key = await native.SwapMasterKey.createFromSeed(
          seed: seed,
          network: native.Network.testnet,
        );
        final regtestKey = await native.SwapMasterKey.createFromSeed(
          seed: seed,
          network: native.Network.regtest,
        );
        seed.fillRange(0, seed.length, 0);
        expect(regtestKey.fingerprint, key.fingerprint);
        final db = BoltzSwapsDatabase(NativeDatabase.memory());
        final regtestDb = BoltzSwapsDatabase(NativeDatabase.memory());
        final keychain = _ReadBarrierKeychain();
        final storage = SwapStorage(
          rows: DriftSwapRowStore(db),
          secrets: keychain.capability,
        );
        final regtestStorage = storage.regtestView(
          rows: DriftSwapRowStore(regtestDb),
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
        BoltzSwapRepository repository({
          NetworkEnv environment = NetworkEnv.testnet,
        }) => BoltzSwapRepository.connect(
          url: 'http://127.0.0.1:${server.port}',
          storage: environment == NetworkEnv.regtest ? regtestStorage : storage,
          environment: environment,
          webSocketUrl: environment == NetworkEnv.regtest
              ? 'ws://127.0.0.1:${server.port}'
              : null,
          electrum: ReproElectrumBackend(),
          lockupChain: ReproChainBackend(),
          newAddressFor: (_) async =>
              Ok('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx'),
          walletTx: (_, {required walletId}) async => null,
          walletTxs: (_, {bool sync = false}) async => const [],
          fastestFee: ({
            required txSize,
            required isLiquid,
            required environment,
          }) async => 1,
          wallets: ({required environment}) async => const [
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
          swapMasterKeySource: ({required environment}) async =>
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
            environment: NetworkEnv.testnet,
          ),
        );
        final nextEnvironment = crossEnvironment
            ? NetworkEnv.regtest
            : NetworkEnv.testnet;
        final second = repository(environment: nextEnvironment);
        if (crossEnvironment) {
          await second.storeSwapMasterKey(
            DerivedSwapMasterKey(
              walletFingerprint: 'test-root',
              xprv: regtestKey.xprv,
              xpub: regtestKey.xpub,
              mnemonic: regtestKey.mnemonic,
              fingerprint: regtestKey.fingerprint,
              environment: NetworkEnv.regtest,
            ),
          );
        }
        addTearDown(() async {
          first.dispose();
          second.dispose();
          await server.close(force: true);
          await listener.cancel();
          await db.close();
          await regtestDb.close();
        });
        final engine = SwitchableSwapEngine((
          store: SwapStoreImpl(
            storage: storage,
            environment: NetworkEnv.testnet,
          ),
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
            store: SwapStoreImpl(
              storage: crossEnvironment ? regtestStorage : storage,
              environment: nextEnvironment,
            ),
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

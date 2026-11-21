import 'package:primitives/primitives.dart' show NetworkEnv;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:preferences/storage.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/swaps_adapters.dart';
import 'package:preferences/preferences.dart' as settings;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' as primitives;
import 'package:swaps/swaps.dart';
import 'package:sync/sync.dart' as sync;

import 'support/real_swap_backends.dart';

// Selects a real local Electrum endpoint and executes the actual sync call.
// Neither the adapter nor decoding/broadcast/repository logic is replaced.
class _Connections implements sync.WalletConnectionPort {
  final int port;
  _Connections(this.port);

  @override
  Future<primitives.Result<T, sync.SyncFailure>> run<T>({
    required primitives.Network network,
    required Future<primitives.Result<T, sync.SyncFailure>> Function(
      sync.WalletConnection,
    )
    operation,
    required bool Function(sync.SyncFailure) mayRetry,
  }) => operation(
    sync.WalletConnection(
      url: 'tcp://127.0.0.1:$port',
      timeout: const Duration(seconds: 2),
      retry: 0,
      stopGap: 10,
      validateDomain: false,
    ),
  );
}

// Scheduling seam around the actual SQLite-backed settings read.
class _HeldSettings extends SettingsRepositoryImpl {
  bool hold = false;
  final entered = Completer<void>();
  final release = Completer<void>();

  _HeldSettings({required super.settingsDatasource});

  @override
  Future<settings.SettingsEntity> fetch() async {
    final value = await super.fetch();
    if (hold) {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    }
    return value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final (authorized, suspended) in [
    (true, false),
    (false, false),
    (true, true),
  ]) {
    test(
      'R2 reopened pending lockup ${suspended
          ? 'suspended during authorization'
          : authorized
          ? 'authorized control'
          : 'requires current broadcast authorization'}',
      () async {
        // Existing public synthetic transaction fixture, containing no key material.
        // It need not be spendable: the backend rejects it. The assertion is that
        // an unauthorized request must not reach that backend at all.
        const psbt =
            'cHNidP8BAFICAAAAAQECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gAAAAAAD9////'
            'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
            'MzMzMzMzMzMzMzMzMzMzMzMAAA==';
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final sockets = <Socket>[];
        var broadcastCalls = 0;
        final listener = server.listen((socket) {
          sockets.add(socket);
          socket
              .cast<List<int>>()
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .listen((line) {
                final request = jsonDecode(line) as Map<String, dynamic>;
                final method = request['method'];
                final response = <String, Object?>{
                  'jsonrpc': '2.0',
                  'id': request['id'],
                };
                if (method == 'server.version') {
                  response['result'] = ['reproduction-backend', '1.4'];
                } else if (method == 'blockchain.transaction.get') {
                  response['error'] = {
                    'code': 1,
                    'message': 'No such mempool or blockchain transaction',
                  };
                } else if (method == 'blockchain.transaction.broadcast') {
                  broadcastCalls++;
                  response['error'] = {
                    'code': -26,
                    'message': 'fixture-rejected-transaction',
                  };
                } else {
                  response['result'] = null;
                }
                socket.write('${jsonEncode(response)}\n');
              });
        });
        final appDb = SqliteDatabase(NativeDatabase.memory());
        await appDb.customStatement(
          'UPDATE settings SET is_superuser = 1, is_dev_mode_enabled = 1 WHERE id=1',
        );
        final preferences = _HeldSettings(
          settingsDatasource: PreferencesDao(appDb),
        );
        await preferences.setEnvironment(settings.Environment.testnet);
        final directory = await Directory.systemTemp.createTemp(
          'review3141-r2-',
        );
        final file = File('${directory.path}/swaps.sqlite');
        final secrets = ReproKeychainBackend();
        BoltzSwapsDatabase db = BoltzSwapsDatabase(NativeDatabase(file));
        SwapStorage storage = SwapStorage(
          rows: DriftSwapRowStore(db),
          secrets: secrets.capability,
        );
        final chain = AppLockupChain(
          _Connections(server.port),
          settingsRepository: preferences,
        );
        BoltzSwapRepository repository() => BoltzSwapRepository.connect(
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
        final first = repository();
        const id = 'R20000000001';
        await storage.store(
          SwapModel.lnSend(
            id: id,
            type: SwapType.bitcoinToLightning.name,
            status: SwapStatus.pending.name,
            isTestnet: true,
            keyIndex: 0,
            creationTime: DateTime.now().millisecondsSinceEpoch,
            sendWalletId: 'test-wallet',
            paymentAddress: 'fixture-address',
            paymentAmount: 100000,
            invoice: 'unused-by-pending-resolution',
          ),
        );
        final recorded = await first.recordPendingLockup(
          swapId: id,
          signedTx: psbt,
        );
        expect(
          recorded,
          isA<primitives.Ok<Swap, SwapsFailure>>(),
          reason:
              'The real pending-recording path must parse/persist this PSBT',
        );
        first.dispose();
        await db.close();
        db = BoltzSwapsDatabase(NativeDatabase(file));
        storage = SwapStorage(
          rows: DriftSwapRowStore(db),
          secrets: secrets.capability,
        );
        final reopened = repository();
        addTearDown(() async {
          reopened.dispose();
          await db.close();
          await preferences.close();
          await appDb.close();
          for (final socket in sockets) {
            socket.destroy();
          }
          await server.close();
          await listener.cancel();
          await directory.delete(recursive: true);
        });
        if (!authorized) await preferences.setIsDevMode(false);
        expect((await preferences.fetch()).isDevModeEnabled, authorized);
        final persistedModel = await storage.fetch(id);
        if (persistedModel == null) {
          fail('Pending lockup must survive reopening');
        }
        final persisted = persistedModel.toEntity() as LnSendSwap;
        expect(persisted.hasPendingLockup, isTrue);

        preferences.hold = suspended;
        final resolving = reopened.resolve(persisted);
        if (suspended) {
          await preferences.entered.future.timeout(const Duration(seconds: 3));
          reopened.suspendEffects();
          preferences.release.complete();
        }
        final result = await resolving;
        if (suspended) {
          expect(
            result,
            isA<primitives.Err<Swap, SwapsFailure>>().having(
              (result) => result.failure,
              'failure',
              isA<SwapsBusyFailure>(),
            ),
          );
          final retained = (await storage.fetch(id))?.toEntity() as LnSendSwap?;
          expect(retained?.pendingLockupTx, psbt);
          expect(retained?.pendingLockupTxid, persisted.pendingLockupTxid);
        }
        if (!authorized) {
          expect(
            result,
            isA<primitives.Err<Swap, SwapsFailure>>().having(
              (result) => result.failure,
              'failure',
              isA<SwapsAuthorizationFailure>(),
            ),
          );
          final retained = (await storage.fetch(id))?.toEntity() as LnSendSwap?;
          expect(retained?.pendingLockupTx, psbt);
          expect(retained?.pendingLockupTxid, persisted.pendingLockupTxid);
          await appDb.close();
          expect(
            await reopened.resolve(persisted),
            isA<primitives.Err<Swap, SwapsFailure>>().having(
              (result) => result.failure,
              'failure',
              isA<SwapsAuthorizationFailure>(),
            ),
          );
        }

        expect(
          broadcastCalls,
          authorized && !suspended ? 1 : 0,
          reason:
              'A recorded lockup is evidence, not authorization to bypass '
              'the current test-network broadcast gate after reopening',
        );
      },
    );
  }
}

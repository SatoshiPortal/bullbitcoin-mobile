import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/electrum_sync_fixture.dart';

Future<void> _crashWorker(SendPort replies) async {
  final requests = ReceivePort();
  replies.send(requests.sendPort);
  await requests.first;
  Isolate.exit();
}

class _UnsendableSyncException implements Exception {
  final ReceivePort nativeResource;
  _UnsendableSyncException(this.nativeResource);
  @override
  String toString() => 'synthetic unsendable sync failure';
}

Future<void> _failWithUnsendableError(SendPort replies) async {
  final requests = ReceivePort();
  replies.send(requests.sendPort);
  await requests.first;
  final resource = ReceivePort();
  try {
    throw _UnsendableSyncException(resource);
  } finally {
    resource.close();
  }
}

Future<void> _failBeforeHandshake(SendPort replies) async {
  final resource = ReceivePort();
  try {
    throw _UnsendableSyncException(resource);
  } finally {
    resource.close();
  }
}

Future<void> _failAfterHandshake(SendPort replies) async {
  final requests = ReceivePort();
  replies.send(requests.sendPort);
  // Keep the port alive to reproduce a failed entrypoint with no request loop.
  throw _UnsendableSyncException(requests);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PublicBdkWalletModel wallet;
  late BdkWalletDatasource datasource;
  late ElectrumSyncServer server;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bdk_sync_cache_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async {
            return call.method == 'getApplicationDocumentsDirectory'
                ? directory.path
                : null;
          },
        );
    final key = bdk.DescriptorSecretKey(
      networkKind: bdk.NetworkKind.test,
      mnemonic: bdk.Mnemonic.fromString(mnemonic: testMnemonic),
      password: null,
    );
    wallet =
        WalletModel.publicBdk(
              id: 'sync-cache-test',
              externalDescriptor: bdk.Descriptor.newBip84(
                secretKey: key,
                keychainKind: bdk.KeychainKind.external_,
                networkKind: bdk.NetworkKind.test,
              ).toString(),
              internalDescriptor: bdk.Descriptor.newBip84(
                secretKey: key,
                keychainKind: bdk.KeychainKind.internal,
                networkKind: bdk.NetworkKind.test,
              ).toString(),
              isTestnet: true,
            )
            as PublicBdkWalletModel;
    final bdkWallet = await BdkFacade.createWallet(wallet);
    // Leave index 5 unrevealed: only a discovery scan can find its history.
    final receivingScript = bdkWallet
        .peekAddress(keychain: bdk.KeychainKind.external_, index: 5)
        .address
        .scriptPubkey();
    await BdkFacade.saveWallet(bdkWallet, wallet.hexId);
    server = await ElectrumSyncServer.start(receivingScript);
    datasource = BdkWalletDatasource();
  });

  tearDown(() async {
    await datasource.dispose();
    await server.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await directory.delete(recursive: true);
  });

  Future<void> sync() =>
      datasource.sync(wallet: wallet, electrumServer: server.connection);

  test('an unsupported wallet does not leave a cached failed sync', () async {
    final invalid = WalletModel.publicLwk(
      id: wallet.id,
      combinedCtDescriptor: 'unused',
      isTestnet: true,
    );
    try {
      await datasource.sync(wallet: invalid, electrumServer: server.connection);
      fail('An unsupported wallet must be rejected');
    } catch (error) {
      expect(error, isA<Error>());
    }
    expect(datasource.isWalletSyncing(walletId: wallet.id), isFalse);
    await sync();
    expect(server.requestedScripts, contains(server.scriptHash));
  });

  test('a failure after handshake terminates the worker promptly', () async {
    await datasource.dispose();
    datasource = BdkWalletDatasource(syncWorkerEntryPoint: _failAfterHandshake);
    await expectLater(
      sync().timeout(const Duration(seconds: 2)),
      throwsA(
        isA<BdkSyncException>().having(
          (error) => error.sourceType,
          'sourceType',
          '_UnsendableSyncException',
        ),
      ),
    );
    expect(datasource.isWalletSyncing(walletId: wallet.id), isFalse);
  });

  test('first sync discovers funds at an unrevealed address', () async {
    await sync();
    final restored = await BdkFacade.createWallet(wallet);
    expect(
      restored.listOutput().map((output) => output.outpoint.txid.toString()),
      contains(server.txid),
    );
    expect(server.requestedScripts, contains(server.scriptHash));
  });

  test('successive syncs reuse cached transaction data', () async {
    await sync();
    expect(server.transactionRequests, 1);
    final restored = await BdkFacade.createWallet(wallet);
    final unrevealedScript = restored
        .peekAddress(keychain: bdk.KeychainKind.external_, index: 30)
        .address
        .scriptPubkey();
    expect(server.requestedScripts, contains(scriptHashFor(unrevealedScript)));
    server.requestedScripts.clear();
    await sync();
    expect(server.requestedScripts, contains(server.scriptHash));
    expect(
      server.requestedScripts,
      isNot(contains(scriptHashFor(unrevealedScript))),
      reason: 'ordinary sync must not repeat stop-gap discovery',
    );
    expect(
      server.transactionRequests,
      1,
      reason:
          'unchanged history must reuse the Electrum client transaction cache',
    );
  });

  test('subsequent sync reloads newly persisted receive addresses', () async {
    await sync();
    final next = await datasource.getNewAddress(wallet: wallet);
    final address = bdk.Address(
      address: next.address,
      network: bdk.Network.testnet,
    );
    server.requestedScripts.clear();
    await sync();
    expect(
      server.requestedScripts,
      contains(scriptHashFor(address.scriptPubkey())),
    );
    expect(server.transactionRequests, 1);
  });

  test(
    'a stop gap change repeats discovery without losing the client cache',
    () async {
      await sync();
      final initial = server.connection;
      final restored = await BdkFacade.createWallet(wallet);
      try {
        for (final gap in [40, 10]) {
          final unused = scriptHashFor(
            restored
                .peekAddress(
                  keychain: bdk.KeychainKind.external_,
                  index: gap == 40 ? 30 : 8,
                )
                .address
                .scriptPubkey(),
          );
          final changed = ElectrumConnection(
            url: initial.url,
            retry: initial.retry,
            timeout: initial.timeout,
            stopGap: gap,
            validateDomain: initial.validateDomain,
            isCustom: initial.isCustom,
            socks5: initial.socks5,
          );
          server.requestedScripts.clear();
          await datasource.sync(wallet: wallet, electrumServer: changed);
          expect(
            server.requestedScripts,
            contains(unused),
            reason: 'Changing the stop gap must trigger fresh discovery',
          );
          expect(server.connections, 1);
          expect(
            server.transactionRequests,
            1,
            reason: 'The existing transaction cache remains valid',
          );
          server.requestedScripts.clear();
          await datasource.sync(wallet: wallet, electrumServer: changed);
          expect(
            server.requestedScripts,
            isNot(contains(unused)),
            reason: 'An unchanged stop gap must return to incremental sync',
          );
          expect(server.connections, 1);
          expect(server.transactionRequests, 1);
        }
      } finally {
        restored.dispose();
      }
    },
  );

  test('switching Electrum server starts a fresh client', () async {
    await sync();
    final restored = await BdkFacade.createWallet(wallet);
    final script = restored
        .peekAddress(keychain: bdk.KeychainKind.external_, index: 5)
        .address
        .scriptPubkey();
    final otherServer = await ElectrumSyncServer.start(script);
    try {
      await datasource.sync(
        wallet: wallet,
        electrumServer: otherServer.connection,
      );
      expect(
        otherServer.transactionRequests,
        1,
        reason:
            'a server change must not reuse the previous connection or cache',
      );
      expect(server.transactionRequests, 1);
    } finally {
      await otherServer.close();
    }
  });

  test('a server switch preserves completed wallet discovery', () async {
    await sync();
    final restored = await BdkFacade.createWallet(wallet);
    final script = restored
        .peekAddress(keychain: bdk.KeychainKind.external_, index: 5)
        .address
        .scriptPubkey();
    final unrevealed = restored
        .peekAddress(keychain: bdk.KeychainKind.external_, index: 30)
        .address
        .scriptPubkey();
    final other = await ElectrumSyncServer.start(script);
    try {
      await datasource.sync(wallet: wallet, electrumServer: other.connection);
      expect(
        other.requestedScripts,
        isNot(contains(scriptHashFor(unrevealed))),
      );
      expect(other.transactionRequests, 1);
    } finally {
      await other.close();
    }
  });

  test('a failed refresh does not discard completed discovery', () async {
    await sync();
    server.failHistory = true;
    await expectLater(sync(), throwsA(isA<Exception>()));
    server.failHistory = false;
    server.requestedScripts.clear();
    await sync();
    final restored = await BdkFacade.createWallet(wallet);
    final unrevealed = restored
        .peekAddress(keychain: bdk.KeychainKind.external_, index: 30)
        .address
        .scriptPubkey();
    expect(server.requestedScripts, isNot(contains(scriptHashFor(unrevealed))));
  });

  test('a worker crash does not prevent wallet deletion', () async {
    await datasource.dispose();
    datasource = BdkWalletDatasource(syncWorkerEntryPoint: _crashWorker);
    final active = sync();
    final activeCheck = expectLater(active, throwsA(isA<Exception>()));
    final deleting = expectLater(datasource.delete(wallet: wallet), completes);
    await Future.wait([
      activeCheck,
      deleting,
    ]).timeout(const Duration(seconds: 10));
    expect(
      await File(await BdkFacade.databasePathFor(wallet.hexId)).exists(),
      isFalse,
    );
  });

  test('a worker crash does not interrupt datasource disposal', () async {
    await datasource.dispose();
    datasource = BdkWalletDatasource(syncWorkerEntryPoint: _crashWorker);
    final startedDone = datasource.walletSyncStartedStream.drain<void>();
    final finishedDone = datasource.walletSyncFinishedStream.drain<void>();
    final activeCheck = expectLater(sync(), throwsA(isA<Exception>()));
    final disposing = expectLater(datasource.dispose(), completes);
    await Future.wait([
      activeCheck,
      disposing,
      startedDone,
      finishedDone,
    ]).timeout(const Duration(seconds: 10));
  });

  test('an unsendable worker failure retains its diagnosis', () async {
    await datasource.dispose();
    datasource = BdkWalletDatasource(
      syncWorkerEntryPoint: _failWithUnsendableError,
    );
    await expectLater(
      sync(),
      throwsA(
        predicate<Object>(
          (error) =>
              error is Exception &&
              error.toString().contains('_UnsendableSyncException'),
        ),
      ),
    );
  });

  test(
    'retry zero recovers from an idle disconnect on the next attempt',
    () async {
      await sync();
      server.disconnectClients();
      await expectLater(sync(), throwsA(isA<Exception>()));
      server.requestedScripts.clear();
      await sync();
      final restored = await BdkFacade.createWallet(wallet);
      final unrevealed = restored
          .peekAddress(keychain: bdk.KeychainKind.external_, index: 30)
          .address
          .scriptPubkey();
      expect(
        server.requestedScripts,
        isNot(contains(scriptHashFor(unrevealed))),
      );
    },
  );

  test(
    'a failed worker startup retains its diagnosis and can be disposed',
    () async {
      await datasource.dispose();
      datasource = BdkWalletDatasource(
        syncWorkerEntryPoint: _failBeforeHandshake,
      );
      await expectLater(
        sync(),
        throwsA(
          predicate<Object>(
            (error) =>
                error is Exception &&
                error.toString().contains('_UnsendableSyncException'),
          ),
        ),
      );
      await datasource.dispose();
    },
  );

  test(
    'idle workers close their connections without discarding discovery',
    () async {
      await datasource.dispose();
      datasource = BdkWalletDatasource(idleWorkerTimeout: Duration.zero);
      await sync();
      await server.firstDisconnect.future.timeout(const Duration(seconds: 3));
      server.requestedScripts.clear();
      await sync();
      expect(server.connections, 2);
      expect(server.transactionRequests, 2);
      final restored = await BdkFacade.createWallet(wallet);
      final unrevealed = restored
          .peekAddress(keychain: bdk.KeychainKind.external_, index: 30)
          .address
          .scriptPubkey();
      expect(
        server.requestedScripts,
        isNot(contains(scriptHashFor(unrevealed))),
      );
    },
  );

  test(
    'native retry reconnects a dropped socket and retains cached transactions',
    () async {
      final original = server.connection;
      final retrying = ElectrumConnection(
        url: original.url,
        retry: 1,
        timeout: original.timeout,
        stopGap: original.stopGap,
        validateDomain: original.validateDomain,
        isCustom: original.isCustom,
      );
      await datasource.sync(wallet: wallet, electrumServer: retrying);
      expect(server.transactionRequests, 1);
      server.disconnectClients();
      await datasource
          .sync(wallet: wallet, electrumServer: retrying)
          .timeout(const Duration(seconds: 10));
      expect(server.connections, 2);
      expect(server.transactionRequests, 1);
    },
  );

  test(
    'discovery activity replays to late observers and ignores incremental sync',
    () async {
      final events = <bool>[];
      final subscription = datasource.discoveryInProgressStream.listen(
        events.add,
      );
      addTearDown(subscription.cancel);
      final gate = Completer<void>();
      server.historyGate = gate;
      final first = sync();
      await server.historyStarted.future.timeout(const Duration(seconds: 10));
      await pumpEventQueue();
      expect(events, [false, true]);
      expect(await datasource.discoveryInProgressStream.first, isTrue);
      gate.complete();
      await first;
      await pumpEventQueue();
      expect(events, [false, true, false]);
      events.clear();
      await sync();
      await pumpEventQueue();
      expect(events, isEmpty);

      final database = File(await BdkFacade.databasePathFor(wallet.hexId));
      await database.writeAsString('corrupt SQLite fixture', flush: true);
      await sync();
      await pumpEventQueue();
      expect(events, [
        true,
        false,
      ], reason: 'Worker-side database recovery is discovery too');
    },
  );

  test('failed full discovery clears its activity indicator', () async {
    final events = <bool>[];
    final subscription = datasource.discoveryInProgressStream.listen(
      events.add,
    );
    addTearDown(subscription.cancel);
    server.failHistory = true;
    await expectLater(sync(), throwsA(isA<Exception>()));
    await pumpEventQueue();
    expect(events, [false, true, false]);
  });

  test('simultaneous syncs for the same wallet share one execution', () async {
    final gate = Completer<void>();
    server.historyGate = gate;
    final first = sync();
    await server.historyStarted.future.timeout(const Duration(seconds: 10));
    final second = sync();
    gate.complete();
    await Future.wait([first, second]).timeout(const Duration(seconds: 10));
    expect(datasource.syncExecutions[wallet.id], 1);
    expect(server.transactionRequests, 1);
  });

  test('failed discovery is retried before ordinary revealed sync', () async {
    server.failHistory = true;
    await expectLater(sync(), throwsA(isA<Exception>()));
    server.failHistory = false;
    server.requestedScripts.clear();
    await sync();
    final restored = await BdkFacade.createWallet(wallet);
    final unrevealedScript = restored
        .peekAddress(keychain: bdk.KeychainKind.external_, index: 30)
        .address
        .scriptPubkey();
    expect(server.requestedScripts, contains(scriptHashFor(unrevealedScript)));
    expect(
      restored.listOutput().map((output) => output.outpoint.txid.toString()),
      contains(server.txid),
    );
  });

  test(
    'deletion waits for sync and rejects new work until the database is removed',
    () async {
      final databasePath = await BdkFacade.databasePathFor(wallet.hexId);
      final gate = Completer<void>();
      server.historyGate = gate;
      final active = sync();
      await server.historyStarted.future.timeout(const Duration(seconds: 10));
      final deletion = datasource.delete(wallet: wallet);
      expect(sync, throwsStateError);
      gate.complete();
      await Future.wait([
        active,
        deletion,
      ]).timeout(const Duration(seconds: 10));
      expect(await File(databasePath).exists(), isFalse);
      expect(datasource.syncExecutions[wallet.id], 1);
    },
  );
}

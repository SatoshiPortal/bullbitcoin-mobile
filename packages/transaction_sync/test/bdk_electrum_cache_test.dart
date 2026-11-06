import 'support/connections.dart';
import 'package:transaction_sync/write.dart';
import 'package:transaction_sync/src/write/writer_lock.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:transaction_sync/src/data/bdk_electrum_cache.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'support/electrum_fixture.dart';

const _testMnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';

(String, String) _descriptors() {
  final secretKey = bdk.DescriptorSecretKey(
    networkKind: bdk.NetworkKind.test,
    mnemonic: bdk.Mnemonic.fromString(mnemonic: _testMnemonic),
    password: null,
  );
  String derive(bdk.KeychainKind keychain) => bdk.Descriptor.newBip84(
    secretKey: secretKey,
    keychainKind: keychain,
    networkKind: bdk.NetworkKind.test,
  ).toString();
  return (
    derive(bdk.KeychainKind.external_),
    derive(bdk.KeychainKind.internal),
  );
}

final class _Wallet {
  final bdk.Wallet wallet;
  final bdk.Persister persister;

  _Wallet(this.wallet, this.persister);

  factory _Wallet.open(String path) {
    final (external, internal) = _descriptors();
    final existed = File(path).existsSync();
    final persister = bdk.Persister.newSqlite(path: path);
    final e = bdk.Descriptor(
      descriptor: external,
      networkKind: bdk.NetworkKind.test,
    );
    final i = bdk.Descriptor(
      descriptor: internal,
      networkKind: bdk.NetworkKind.test,
    );
    final wallet = existed
        ? bdk.Wallet.load(
            descriptor: e,
            changeDescriptor: i,
            persister: persister,
            lookahead: 25,
          )
        : bdk.Wallet(
            descriptor: e,
            changeDescriptor: i,
            network: bdk.Network.testnet,
            persister: persister,
            lookahead: 25,
          );
    return _Wallet(wallet, persister);
  }

  void close() {
    wallet.dispose();
    persister.dispose();
  }
}

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Map<String, String> _walletScripts() {
  final dir = Directory.systemTemp.createTempSync('wts_cache_scripts_');
  final open = _Wallet.open('${dir.path}/w.sqlite');
  try {
    String script(bdk.KeychainKind keychain, int index) => _hex(
      open.wallet
          .peekAddress(keychain: keychain, index: index)
          .address
          .scriptPubkey()
          .toBytes(),
    );
    return {
      for (var i = 0; i < 6; i++)
        'ext$i': script(bdk.KeychainKind.external_, i),
      for (var i = 0; i < 3; i++) 'int$i': script(bdk.KeychainKind.internal, i),
    };
  } finally {
    open.close();
    dir.deleteSync(recursive: true);
  }
}

/// The wallet's view of each fixture transaction, in the fixture's format.
Map<String, String> _observe(bdk.Wallet wallet, Map<String, String> ids) => {
  for (final MapEntry(key: name, value: txid) in ids.entries)
    if (wallet.getTx(txid: bdk.Txid.fromString(hex: txid)) case final tx?)
      name: switch (tx.chainPosition) {
        bdk.ConfirmedChainPosition(:final confirmationBlockTime) =>
          'confirmed@${confirmationBlockTime.blockId.height}:'
              '${confirmationBlockTime.blockId.hash.toString().substring(0, 8)}',
        _ => 'mempool',
      },
};

/// One full scan with a fresh client, the way the app syncs, optionally
/// through the cache.
void _scan(ElectrumFixture fixture, String path, {required bool cached}) {
  final open = _Wallet.open(path);
  final cache = cached ? BdkElectrumCache.open(path) : null;
  final client = bdk.ElectrumClient(
    url: fixture.url,
    socks5: null,
    timeout: 5,
    retry: 0,
    validateDomain: false,
  );
  try {
    open.wallet.revealAddressesTo(
      keychain: bdk.KeychainKind.external_,
      index: 2,
    );
    open.wallet.revealAddressesTo(
      keychain: bdk.KeychainKind.internal,
      index: 0,
    );
    cache?.prefill(client, open.wallet);
    final update = client.fullScan(
      request: open.wallet.startFullScan().build(),
      stopGap: 20,
      batchSize: 50,
      fetchPrevTxouts: true,
    );
    open.wallet.applyUpdate(update: update);
    open.wallet.persist(persister: open.persister);
    cache?.rememberParents(client, open.wallet);
  } finally {
    client.dispose();
    cache?.close();
    open.close();
  }
}

typedef _Run = ({
  Map<String, String> seen,
  Map<String, String> truth,
  FixtureRequests requests,
});

Future<_Run> _run(
  ElectrumFixture fixture,
  String scenario, {
  required bool cached,
}) async {
  final dir = Directory.systemTemp.createTempSync('wts_cache_');
  try {
    final path = '${dir.path}/w.sqlite';
    await fixture.load(scenario, 0);
    _scan(fixture, path, cached: cached);
    final phase = await fixture.load(scenario, 1);
    await fixture.requests();
    _scan(fixture, path, cached: cached);
    final requests = await fixture.requests();
    final reopened = _Wallet.open(path);
    try {
      return (
        seen: _observe(reopened.wallet, phase.ids),
        truth: phase.truth,
        requests: requests,
      );
    } finally {
      reopened.close();
    }
  } finally {
    dir.deleteSync(recursive: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ElectrumFixture fixture;

  setUpAll(() async => fixture = await ElectrumFixture.start(_walletScripts()));
  final logs = Directory.systemTemp.createTempSync('sync_logs_');
  setUpAll(() {
    log = Logger.replace(directory: logs);
  });
  tearDownAll(() async {
    fixture.close();
    await log.flush();
    logs.deleteSync(recursive: true);
  });

  group('writer operation', () {
    late Directory dir;
    late BitcoinWalletDescriptor descriptor;
    late String path;
    late FixtureConnections connections;
    late ElectrumSync sync;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('electrum_writer_');
      final (external, internal) = _descriptors();
      descriptor = BitcoinWalletDescriptor(
        key: WalletKey(id: 'installed-wallet', network: BitcoinNetwork.testnet),
        scriptType: ScriptType.bip84,
        origin: 'fixture',
        externalDescriptor: external,
        internalDescriptor: internal,
      );
      path = nativeWalletStoragePath(dir.path, descriptor.key);
      final installed = _Wallet.open(path);
      installed.wallet.revealAddressesTo(
        keychain: bdk.KeychainKind.external_,
        index: 2,
      );
      installed.wallet.revealAddressesTo(
        keychain: bdk.KeychainKind.internal,
        index: 0,
      );
      installed.wallet.persist(persister: installed.persister);
      installed.close();
      connections = FixtureConnections([fixture.url]);
      sync = ElectrumSync(
        connections: connections,
        documentsDirectory: () async => dir.path,
      );
    });
    tearDown(() => dir.deleteSync(recursive: true));

    SyncCompletion completed(
      Result<SyncCompletion, TransactionSyncFailure> result,
    ) => switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError(
        'Unexpected ${failure.runtimeType}',
      ),
    };

    for (final scenario in electrumFixtureScenarios) {
      test('first scan then routine/discovery parity: $scenario', () async {
        await fixture.load(scenario, 0);
        expect(
          completed(await sync.execute(descriptor)).mode,
          SyncMode.initialScan,
        );
        final phase = await fixture.load(scenario, 1);
        await fixture.requests();
        final discovery = scenario == 'S7-incoming-unrevealed-in-gap';
        expect(
          completed(await sync.execute(descriptor, discover: discovery)).mode,
          discovery ? SyncMode.discovery : SyncMode.revealedScripts,
        );
        final reopened = _Wallet.open(path);
        try {
          expect(_observe(reopened.wallet, phase.ids), phase.truth);
        } finally {
          reopened.close();
        }
        expect(connections.routeActive, isFalse);
      });
    }

    test(
      'routine skips unrevealed scripts; explicit discovery finds them',
      () async {
        await fixture.load('S7-incoming-unrevealed-in-gap', 0);
        completed(await sync.execute(descriptor));
        final phase = await fixture.load('S7-incoming-unrevealed-in-gap', 1);
        completed(await sync.execute(descriptor));
        var reopened = _Wallet.open(path);
        expect(_observe(reopened.wallet, phase.ids), isNot(contains('T4')));
        reopened.close();
        completed(await sync.execute(descriptor, discover: true));
        reopened = _Wallet.open(path);
        expect(_observe(reopened.wallet, phase.ids), phase.truth);
        reopened.close();
      },
    );

    test(
      'concurrent routine calls share one operation and paired events',
      () async {
        await fixture.load('S10-no-change', 0);
        final started = <WalletKey>[];
        final finished = <SyncFinished>[];
        final a = sync.started.listen(started.add);
        final b = sync.finished.listen(finished.add);
        addTearDown(a.cancel);
        addTearDown(b.cancel);
        final first = sync.execute(descriptor);
        final second = sync.execute(descriptor);
        expect(identical(first, second), isTrue);
        expect(sync.isSyncing(walletId: descriptor.key.id), isTrue);
        completed(await first);
        await Future<void>.delayed(Duration.zero);
        expect(started, hasLength(1));
        expect(finished, hasLength(1));
        expect(sync.isSyncing(), isFalse);
      },
    );

    test('sync diagnostics persist without wallet data', () async {
      await fixture.load(electrumFixtureScenarios.first, 0);
      final before = (await log.readLogs()).length;
      completed(await sync.execute(descriptor));
      final lines = (await log.readLogs()).skip(before).join('\n');
      expect(lines, contains('Electrum sync started'));
      expect(lines, contains('Wallet writer lock acquired'));
      expect(lines, contains('Wallet writer operation committed'));
      expect(lines, contains('Electrum sync finished mode=initialScan'));
      expect(lines, contains('cache=ok'));
      expect(lines, contains('route=direct stop_gap=20'));
      expect(lines, isNot(contains('Electrum sync connection network=')));
      expect(lines, isNot(contains(descriptor.key.id)));
      expect(lines, isNot(contains(descriptor.externalDescriptor)));
      expect(lines, isNot(contains(fixture.url)));
    });

    test('persistent failures log once and recovery is persisted', () async {
      await fixture.load(electrumFixtureScenarios.first, 0);
      final before = (await log.readLogs()).length;
      final saved = File(path).readAsBytesSync();
      File(path).deleteSync();
      expect(await sync.execute(descriptor), isA<Err>());
      expect(await sync.execute(descriptor), isA<Err>());
      File(path).writeAsBytesSync(saved);
      completed(await sync.execute(descriptor));
      final lines = (await log.readLogs()).skip(before).toList();
      expect(
        lines.where((line) => line.contains('Electrum sync failed')).length,
        1,
      );
      expect(
        lines.where((line) => line.contains('Electrum sync recovered')).length,
        1,
      );
    });

    test('discovery queued behind a routine call still scans', () async {
      await fixture.load('S10-no-change', 0);
      final first = sync.execute(descriptor);
      final discovery = sync.execute(descriptor, discover: true);
      expect(completed(await first).mode, SyncMode.initialScan);
      expect(completed(await discovery).mode, SyncMode.discovery);
      expect(connections.attempts, 2);
    });

    test('fallback happens before opening the native store', () async {
      await fixture.load('S10-no-change', 0);
      connections = FixtureConnections(['tcp://127.0.0.1:0', fixture.url]);
      sync = ElectrumSync(
        connections: connections,
        documentsDirectory: () async => dir.path,
      );
      completed(await sync.execute(descriptor));
      expect(connections.attempts, 2);
    });

    test('corrupt native store is preserved and never retried', () async {
      File(path).writeAsStringSync('corrupted native wallet');
      connections = FixtureConnections([fixture.url, fixture.url]);
      sync = ElectrumSync(
        connections: connections,
        documentsDirectory: () async => dir.path,
      );
      expect(
        await sync.execute(descriptor),
        isA<Err<SyncCompletion, TransactionSyncFailure>>(),
      );
      expect(connections.attempts, 1);
      expect(File(path).readAsStringSync(), 'corrupted native wallet');
    });

    test('a failed persist does not fallback or report success', () async {
      await fixture.load('S10-no-change', 0);
      await fixture.requests();
      final blocker = sqlite3.open(path);
      blocker.execute(
        "CREATE TRIGGER fail_persist BEFORE INSERT ON bdk_blocks "
        "BEGIN SELECT RAISE(ABORT, 'fixture persist failure'); END",
      );
      connections = FixtureConnections([fixture.url, fixture.url]);
      sync = ElectrumSync(
        connections: connections,
        documentsDirectory: () async => dir.path,
      );
      try {
        final result = await sync.execute(descriptor);
        expect(result, isA<Err<SyncCompletion, TransactionSyncFailure>>());
        if (result case Err(:final failure)) {
          expect(failure, isA<TransactionSyncStorageFailure>());
        }
        expect(connections.attempts, 1);
        expect(
          (await fixture.requests())
              .counts['blockchain.scripthash.get_history'],
          greaterThan(0),
        );
      } finally {
        blocker.execute('DROP TRIGGER fail_persist');
        blocker.dispose();
      }
      final reopened = _Wallet.open(path);
      expect(reopened.wallet.latestCheckpoint().height, 0);
      reopened.close();
      completed(await sync.execute(descriptor));
    });

    test(
      'Liquid warns about SOCKS and still checks the native store',
      () async {
        final liquid = LiquidWalletDescriptor(
          key: WalletKey(id: 'liquid', network: LiquidNetwork.testnet),
          scriptType: ScriptType.bip84,
          origin: 'fixture',
          combinedCtDescriptor:
              'ct(slip77(PRIVACY_PLACEHOLDER),elwpkh(public))',
        );
        connections = FixtureConnections([
          fixture.url,
        ], socks5: '127.0.0.1:9050');
        sync = ElectrumSync(
          connections: connections,
          documentsDirectory: () async => dir.path,
        );
        await fixture.requests();
        final result = await sync.execute(liquid);
        expect(result, isA<Err<SyncCompletion, TransactionSyncFailure>>());
        if (result case Err(:final failure)) {
          expect(failure, isA<TransactionSyncNotFoundFailure>());
        }
        expect((await fixture.requests()).counts, isEmpty);
      },
    );

    test(
      'writer contention skips native sync and emits a visible failure',
      () async {
        final acquisition =
            WriterLock.acquire(writerLockDirectory(dir.path), descriptor.key)
                as Ok<WriterLock, TransactionSyncFailure>;
        try {
          final finished = sync.finished.first;
          final result = await sync.execute(descriptor);
          expect(result, isA<Err<SyncCompletion, TransactionSyncFailure>>());
          expect((result as Err).failure, isA<TransactionSyncBusyFailure>());
          expect((await finished).result, same(result));
          final reopened = _Wallet.open(path);
          expect(reopened.wallet.latestCheckpoint().height, 0);
          reopened.close();
        } finally {
          acquisition.value.release();
        }
      },
    );

    test('successful sync publishes an initialized durable revision', () async {
      await fixture.load(electrumFixtureScenarios.first, 0);
      completed(await sync.execute(descriptor));
      final revisions = RevisionStore(writerMetadataPath(dir.path));
      try {
        final state =
            (await revisions.read(descriptor.key)
                    as Ok<WalletRevisionState, TransactionSyncFailure>)
                .value;
        expect(state.lifecycle, WalletLifecycle.active);
        expect(state.initializedSchema, writerSchemaVersion);
        expect(state.stamp.revision, 2);
      } finally {
        await revisions.close();
      }
    });

    test('missing native store is not created', () async {
      File(path).deleteSync();
      final result = await sync.execute(descriptor);
      expect(result, isA<Err<SyncCompletion, TransactionSyncFailure>>());
      expect(File(path).existsSync(), isFalse);
    });

    test('corrupted prefill sidecar does not change sync outcome', () async {
      await fixture.load('S1-reorg-reconfirmed', 0);
      completed(await sync.execute(descriptor));
      File(BdkElectrumCache.pathFor(path)).writeAsStringSync('bad cache');
      final phase = await fixture.load('S1-reorg-reconfirmed', 1);
      completed(await sync.execute(descriptor));
      final reopened = _Wallet.open(path);
      expect(_observe(reopened.wallet, phase.ids), phase.truth);
      reopened.close();
    });
  });

  group('a prefilled full scan matches the uncached app sync', () {
    for (final scenario in electrumFixtureScenarios) {
      test(scenario, () async {
        final uncached = await _run(fixture, scenario, cached: false);
        final cached = await _run(fixture, scenario, cached: true);

        expect(uncached.seen, uncached.truth, reason: 'reference path');
        expect(cached.seen, uncached.truth);
        // Privacy: the same scripts are queried, and no transaction the
        // uncached sync would not have downloaded.
        expect(cached.requests.scriptHashes, uncached.requests.scriptHashes);
        expect(
          uncached.requests.fetchedTxids.containsAll(
            cached.requests.fetchedTxids,
          ),
          isTrue,
        );
        expect(
          cached.requests.fetchedTxids.length,
          lessThan(uncached.requests.fetchedTxids.length),
        );
      });
    }
  });

  test('an unchanged wallet syncs without downloading transactions', () async {
    final cached = await _run(fixture, 'S10-no-change', cached: true);

    expect(cached.requests.counts['blockchain.transaction.get'], isNull);
    expect(cached.requests.counts['blockchain.transaction.get_merkle'], isNull);
  });

  group('sidecar', () {
    late Directory dir;
    late String path;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('wts_cache_sidecar_');
      path = '${dir.path}/w.sqlite';
    });
    tearDown(() => dir.deleteSync(recursive: true));

    Set<String> storedTxids() {
      final db = sqlite3.open(BdkElectrumCache.pathFor(path));
      try {
        return {
          for (final row in db.select('SELECT txid FROM parent_transaction'))
            row['txid'] as String,
        };
      } finally {
        db.dispose();
      }
    }

    test('stores only the parents the wallet does not own', () async {
      final phase = await fixture.load('S8-outgoing-spend', 1);
      _scan(fixture, path, cached: true);

      // T5 spends the wallet's own T1, whose parent P is foreign.
      expect(storedTxids(), {phase.ids['P']});
    });

    test('drops a stored parent whose bytes do not hash to its txid', () async {
      final phase = await fixture.load('S10-no-change', 0);
      _scan(fixture, path, cached: true);
      final db = sqlite3.open(BdkElectrumCache.pathFor(path));
      db.execute('UPDATE parent_transaction SET raw = ?', [
        Uint8List.fromList([1, 2, 3]),
      ]);
      db.dispose();

      _scan(fixture, path, cached: true);

      // The bad row was dropped by the prefill and fetched again.
      expect(storedTxids(), {phase.ids['P']});
      final check = sqlite3.open(BdkElectrumCache.pathFor(path));
      addTearDown(check.dispose);
      final raw = check.select('SELECT raw FROM parent_transaction').single;
      expect((raw['raw'] as Uint8List).length, greaterThan(3));
    });

    test('an unreadable sidecar is rebuilt', () {
      File(BdkElectrumCache.pathFor(path)).writeAsStringSync('not sqlite');

      final cache = BdkElectrumCache.open(path);
      addTearDown(() => cache?.close());

      expect(cache, isNotNull);
      expect(cache?.rebuilt, isTrue);
      expect(storedTxids(), isEmpty);
    });

    test('a readable sidecar is not reported as rebuilt', () {
      final cache = BdkElectrumCache.open(path);
      addTearDown(() => cache?.close());

      expect(cache?.rebuilt, isFalse);
    });

    test('describe reports the cache state with counts only', () {
      const prefill = (
        transactions: 3,
        parents: 2,
        anchors: 1,
        droppedParents: 0,
        failed: false,
      );
      expect(
        BdkElectrumCache.describe(
          opened: true,
          rebuilt: false,
          prefill: prefill,
          parents: (stored: 4, failed: false),
        ),
        'cache=ok prefilled_txs=3 prefilled_parents=2 anchors=1 '
        'dropped_parents=0 stored_parents=4',
      );
      expect(
        BdkElectrumCache.describe(opened: false, rebuilt: false),
        startsWith('cache=unavailable '),
      );
      expect(
        BdkElectrumCache.describe(
          opened: true,
          rebuilt: true,
          prefill: prefill,
        ),
        startsWith('cache=rebuilt '),
      );
      expect(
        BdkElectrumCache.describe(
          opened: true,
          rebuilt: false,
          prefill: (
            transactions: 0,
            parents: 0,
            anchors: 0,
            droppedParents: 0,
            failed: true,
          ),
        ),
        startsWith('cache=degraded '),
      );
    });

    test('delete removes the sidecar', () async {
      await fixture.load('S10-no-change', 0);
      _scan(fixture, path, cached: true);
      expect(File(BdkElectrumCache.pathFor(path)).existsSync(), isTrue);

      BdkElectrumCache.delete(path);

      expect(File(BdkElectrumCache.pathFor(path)).existsSync(), isFalse);
    });
  });
}

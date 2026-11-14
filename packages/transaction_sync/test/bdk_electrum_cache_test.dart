import 'package:transaction_sync/src/read/persisted_wallet_readiness.dart';
import 'package:transaction_sync/src/write/spend_gate_store_datasource.dart';
import 'package:transaction_sync/src/write/native_store_paths.dart';
import 'package:transaction_sync/src/write/native_wallet_writer_repository.dart';
import 'package:transaction_sync/src/write/revision_store_datasource.dart';
import 'package:transaction_sync/src/write/sqlite_wallet_revision_reader.dart';
import 'support/connections.dart';
import 'support/regtest_wallet.dart';
import 'package:transaction_sync/write.dart';
import 'package:transaction_sync/read.dart';
import 'package:transaction_sync/src/write/writer_lock.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:transaction_sync/src/engine/electrum_cache_datasource.dart';
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
  final cache = cached ? ElectrumCacheDatasource.open(path) : null;
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
      sync = foregroundSync(dir.path, connections);
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

    /// Provisions a store whose only wallet payment, T4, pays [keychain] index
    /// 30, revealed beyond stop gap 20 before the checked pass. With
    /// [scanFirst] the store is scanned before the reveal, so the checked pass
    /// runs above height zero; otherwise it is the store's first scan.
    Future<(SyncMode, Map<String, String>, FixturePhase)> payRevealedIndex30(
      bdk.KeychainKind keychain, {
      required bool scanFirst,
      required bool discover,
    }) async {
      final probe = _Wallet.open(path);
      final script = _hex(
        probe.wallet
            .peekAddress(keychain: keychain, index: 30)
            .address
            .scriptPubkey()
            .toBytes(),
      );
      probe.close();
      File(path).deleteSync();
      final isolated = await ElectrumFixture.start({
        for (final name in _walletScripts().keys) name: '0014${'cd' * 20}',
        'ext5': script,
      });
      addTearDown(isolated.close);
      sync = foregroundSync(dir.path, FixtureConnections([isolated.url]));
      final revisions = RevisionStoreDatasource.openForeground(
        revisionStorePath(dir.path),
      );
      try {
        final writer = NativeWalletWriterRepository(
          revisions: revisions,
          reader: SqliteWalletRevisionReader(revisions),
          documentsDirectory: dir.path,
          catalog: SingleWalletCatalog(descriptor),
          reservedAddresses: NoReservedAddresses(),
        );
        expect(
          await writer.create(descriptor.key, expectedGeneration: 0),
          isA<Ok>(),
        );
      } finally {
        revisions.close();
      }
      await isolated.load('S7-incoming-unrevealed-in-gap', 0);
      if (scanFirst) completed(await sync.execute(descriptor));
      final store = _Wallet.open(path);
      store.wallet.revealAddressesTo(keychain: keychain, index: 30);
      store.wallet.persist(persister: store.persister);
      store.close();
      final phase = await isolated.load('S7-incoming-unrevealed-in-gap', 1);
      final mode = completed(
        await sync.execute(descriptor, discover: discover),
      ).mode;
      final reopened = _Wallet.open(path);
      try {
        return (mode, _observe(reopened.wallet, phase.ids), phase);
      } finally {
        reopened.close();
      }
    }

    for (final keychain in [
      bdk.KeychainKind.external_,
      bdk.KeychainKind.internal,
    ]) {
      test('discovery finds a payment to revealed ${keychain.name} index 30 '
          'beyond stop gap 20', () async {
        final (mode, seen, phase) = await payRevealedIndex30(
          keychain,
          scanFirst: true,
          discover: true,
        );
        expect(mode, SyncMode.discovery);
        expect(seen, {'T4': phase.truth['T4']});
      });
    }

    test(
      'the first scan finds a payment to an index revealed beyond the stop gap',
      () async {
        final (mode, seen, phase) = await payRevealedIndex30(
          bdk.KeychainKind.external_,
          scanFirst: false,
          discover: false,
        );
        expect(mode, SyncMode.initialScan);
        expect(seen, {'T4': phase.truth['T4']});
      },
    );

    // Pinned bdk_chain 0.23.3 discovery misses this payment; revealed scripts must cover it.
    test(
      'revealed scripts find a payment at index 30 beyond stop gap 20',
      () async {
        final installed = _Wallet.open(path);
        final script = _hex(
          installed.wallet
              .peekAddress(keychain: bdk.KeychainKind.external_, index: 30)
              .address
              .scriptPubkey()
              .toBytes(),
        );
        installed.close();
        File(path).deleteSync();
        // Only T4 pays this wallet; the fixture's initial T1 is foreign.
        final isolated = await ElectrumFixture.start({
          for (final name in _walletScripts().keys) name: '0014${'cd' * 20}',
          'ext5': script,
        });
        addTearDown(isolated.close);
        sync = foregroundSync(dir.path, FixtureConnections([isolated.url]));
        final revisions = RevisionStoreDatasource.openForeground(
          revisionStorePath(dir.path),
        );
        final writer = NativeWalletWriterRepository(
          revisions: revisions,
          reader: SqliteWalletRevisionReader(revisions),
          documentsDirectory: dir.path,
          catalog: SingleWalletCatalog(descriptor),
          reservedAddresses: NoReservedAddresses(),
        );
        try {
          expect(
            await writer.create(descriptor.key, expectedGeneration: 0),
            isA<Ok>(),
          );
          await isolated.load('S7-incoming-unrevealed-in-gap', 0);
          expect(
            completed(await sync.execute(descriptor)).mode,
            SyncMode.initialScan,
          );
          for (var index = 0; index <= 30; index++) {
            final issued = await writer.receive(
              descriptor.key,
              expectedGeneration: 1,
              advance: index > 0,
            );
            expect(
              issued,
              isA<Ok<ReceiveAddressIssued, TransactionSyncFailure>>(),
            );
            expect(
              (issued as Ok<ReceiveAddressIssued, TransactionSyncFailure>)
                  .value
                  .index,
              index,
            );
          }
        } finally {
          revisions.close();
        }
        final phase = await isolated.load('S7-incoming-unrevealed-in-gap', 1);
        expect(
          completed(await sync.execute(descriptor, discover: false)).mode,
          SyncMode.revealedScripts,
        );
        final reopened = _Wallet.open(path);
        try {
          expect(_observe(reopened.wallet, phase.ids), {
            'T4': phase.truth['T4'],
          });
        } finally {
          reopened.close();
        }
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
      expect(lines, isNot(contains('event=lease_acquire')));
      expect(
        lines,
        contains('Wallet writer finished intent=sync outcome=committed'),
      );
      expect(lines, matches(r'Electrum sync finished[^\n]*mode=initialScan'));
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
        lines.join(),
        matches(r'Electrum sync failed[^\n]*category=not_found'),
      );
      expect(lines.join(), isNot(contains('category=[REDACTED]')));
      expect(
        lines.where((line) => line.contains('Electrum sync failed')).length,
        1,
      );
      expect(
        lines
            .where(
              (line) =>
                  line.contains('Electrum sync finished') &&
                  line.contains('recovered=true'),
            )
            .length,
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
      sync = foregroundSync(dir.path, connections);
      completed(await sync.execute(descriptor));
      expect(connections.attempts, 2);
    });

    test('the worker never creates the revision store', () async {
      final elsewhere = Directory.systemTemp.createTempSync(
        'electrum_no_store_',
      );
      addTearDown(() => elsewhere.deleteSync(recursive: true));
      File(
        path,
      ).copySync(nativeWalletStoragePath(elsewhere.path, descriptor.key));
      final worker = ElectrumSync(
        connections: FixtureConnections([fixture.url]),
        documentsDirectory: () async => elsewhere.path,
        readRevision: (_) async => const Err(TransactionSyncNotFoundFailure()),
      );
      final result = await worker.execute(descriptor);
      expect(
        (result as Err<SyncCompletion, TransactionSyncFailure>).failure,
        isA<TransactionSyncStorageFailure>(),
      );
      expect(
        Directory('${elsewhere.path}/transaction_sync').existsSync(),
        isFalse,
      );
    });

    test('corrupt native store is preserved and never retried', () async {
      File(path).writeAsStringSync('corrupted native wallet');
      connections = FixtureConnections([fixture.url, fixture.url]);
      sync = foregroundSync(dir.path, connections);
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
      sync = foregroundSync(dir.path, connections);
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
        sync = foregroundSync(dir.path, connections);
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
            WriterLock.acquire((dir.path), descriptor.key)
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

    for (final visible in [true, false]) {
      test('chained send diagnostic: broadcast visible=$visible', () async {
        await fixture.load('S10-no-change', 0);
        completed(await sync.execute(descriptor));
        final revisions = RevisionStoreDatasource.openForeground(
          revisionStorePath(dir.path),
        );
        addTearDown(revisions.close);
        final writer = NativeWalletWriterRepository(
          revisions: revisions,
          reader: SqliteWalletRevisionReader(revisions),
          documentsDirectory: dir.path,
          catalog: SingleWalletCatalog(descriptor),
          reservedAddresses: NoReservedAddresses(),
        );
        final reader = WalletSnapshotReader(
          documentsDirectory: dir.path,
          readiness: PersistedWalletReadiness(revisions),
          requiredSchemaVersion: writerSchemaVersion,
          revisions: SqliteWalletRevisionReader(revisions),
          liquidAdmission: writer,
        );
        Future<WalletReadSnapshot<bdk.Wallet>> read() async =>
            switch (await reader.bitcoin(descriptor)) {
              Ok(:final value) => value,
              Err(:final failure) => throw StateError('$failure'),
            };
        final mnemonic = bdk.Mnemonic.fromString(mnemonic: _testMnemonic);
        final secret = bdk.DescriptorSecretKey(
          networkKind: bdk.NetworkKind.test,
          mnemonic: mnemonic,
          password: null,
        );
        addTearDown(mnemonic.dispose);
        addTearDown(secret.dispose);
        final signers = [
          for (final keychain in [
            bdk.KeychainKind.external_,
            bdk.KeychainKind.internal,
          ])
            bdk.SignersContainer.fromDescriptor(
              descriptor: bdk.Descriptor.newBip84(
                secretKey: secret,
                keychainKind: keychain,
                networkKind: bdk.NetworkKind.test,
              ),
            ),
        ];
        for (final signer in signers) {
          addTearDown(signer.dispose);
        }
        bdk.Transaction build(bdk.Wallet wallet, {int sats = 10000}) {
          final recipient = bdk.Script(
            rawOutputScript: Uint8List.fromList([
              0,
              20,
              ...List.filled(20, 0xab),
            ]),
          );
          final psbt = bdk.TxBuilder()
              .addRecipient(
                script: recipient,
                amount: bdk.Amount.fromSat(satoshi: sats),
              )
              .feeAbsolute(feeAmount: bdk.Amount.fromSat(satoshi: 1000))
              .finish(wallet: wallet);
          try {
            expect(
              wallet.signWithSigners(
                psbt: psbt,
                signers: signers,
                signOptions: null,
              ),
              isTrue,
            );
            return psbt.extractTx();
          } finally {
            psbt.dispose();
            recipient.dispose();
          }
        }

        Set<(String, int)> inputs(bdk.Transaction tx) => {
          for (final input in tx.input())
            (input.previousOutput.txid.toString(), input.previousOutput.vout),
        };
        String change(bdk.Transaction tx, bdk.Wallet wallet) => _hex(
          tx
              .output()
              .singleWhere((o) => wallet.isMine(script: o.scriptPubkey))
              .scriptPubkey
              .toBytes(),
        );

        final before = await read();
        final a = build(before.wallet);
        addTearDown(a.dispose);
        final aId = a.computeTxid().toString();
        final aInputs = inputs(a);
        final aChange = change(a, before.wallet);
        expect(aInputs, hasLength(1));
        await fixture.exposeBroadcasts(visible);
        final client = bdk.ElectrumClient(
          url: fixture.url,
          socks5: null,
          timeout: 5,
          retry: 0,
          validateDomain: false,
        );
        final gate = BitcoinSpendGate(
          documentsDirectory: dir.path,
          revisions: revisions,
          catalog: SingleWalletCatalog(descriptor),
        );
        final admitted = await gate.acquire(descriptor.key);
        expect(admitted, isA<BitcoinSpendAdmission>());
        final admission = admitted as BitcoinSpendAdmission;
        try {
          expect(client.transactionBroadcast(tx: a).toString(), aId);
          expect(admission.accepted(aId).durable, isTrue);
        } finally {
          admission.close();
          client.dispose();
        }
        // A real unrelated checkpoint update forces revision publication even
        // when the accepted broadcast is missing from script histories.
        await fixture.advanceTip();
        final completion = completed(await sync.execute(descriptor));
        final after = await read();
        expect(after.revision.revision, greaterThan(before.revision.revision));
        expect(after.revision, completion.revision);
        expect(after.stale, isFalse);
        expect(identical(after.wallet, before.wallet), isFalse);
        final canonical = after.wallet.getTx(
          txid: bdk.Txid.fromString(hex: aId),
        );
        expect(canonical != null, visible);
        if (!visible) {
          expect(await gate.check(descriptor.key), BitcoinSpendStatus.pending);
          // Restart reads durable state, not a Cubit flag. No second build is
          // admitted until a subsequent successful pass observes the payment.
          final restartedRevisions = RevisionStoreDatasource.openExisting(
            revisionStorePath(dir.path),
          );
          final restarted = BitcoinSpendGate(
            documentsDirectory: dir.path,
            revisions: restartedRevisions,
            catalog: SingleWalletCatalog(descriptor),
          );
          expect(
            await restarted.check(descriptor.key),
            BitcoinSpendStatus.pending,
          );
          restartedRevisions.close();
          await fixture.exposeBroadcasts(true);
          completed(await sync.execute(descriptor));
        }
        expect(await gate.check(descriptor.key), BitcoinSpendStatus.ready);
        final spending = await read();
        final b = build(spending.wallet);
        addTearDown(b.dispose);
        final overlap = inputs(b).intersection(aInputs);
        // Only synthetic booleans/counts: no production wallet data.
        print(
          'CHAINED visible=$visible canonical=${canonical != null} '
          'revisionAdvanced=true fresh=${!after.stale} '
          'overlap=${overlap.length} '
          'spendsChange=${inputs(b).any((i) => i.$1 == aId)} '
          'distinctChange=${change(b, spending.wallet) != aChange}',
        );
        expect(
          overlap,
          isEmpty,
          reason: 'An accepted own broadcast must protect its inputs',
        );
        if (visible) {
          expect(inputs(b).any((i) => i.$1 == aId), isTrue);
          expect(change(b, spending.wallet), isNot(aChange));
        }
        // Later canonical loss must restore the durable barrier, including if
        // the new endpoint omits a previously observed transaction.
        await fixture.exposeBroadcasts(false);
        completed(await sync.execute(descriptor));
        // The native wallet would now spend the payment's input again: only
        // the gate stands between an endpoint's omission and a chained spend.
        final withheld = await read();
        final again = build(withheld.wallet);
        final c = build(withheld.wallet, sats: 11000);
        final d = build(withheld.wallet, sats: 12000);
        for (final tx in [again, c, d]) {
          addTearDown(tx.dispose);
          expect(inputs(tx).intersection(aInputs), isNotEmpty);
        }
        expect(await gate.check(descriptor.key), BitcoinSpendStatus.pending);
        expect(await gate.acquire(descriptor.key), isA<BitcoinSpendRefused>());
        // Repetition, another endpoint and a discovery scan prove nothing more.
        completed(await sync.execute(descriptor));
        final fallback = foregroundSync(
          dir.path,
          FixtureConnections(['tcp://127.0.0.1:1', fixture.url]),
        );
        completed(await fallback.execute(descriptor));
        completed(await sync.execute(descriptor, discover: true));
        expect(await gate.check(descriptor.key), BitcoinSpendStatus.pending);

        bool settled(String txid) {
          final store = SpendGateStoreDatasource.openExisting(
            spendGateStorePath(dir.path),
          );
          try {
            expect(store.tracked(descriptor), contains(txid));
            return store.isObserved(descriptor.key, txid);
          } finally {
            store.close();
          }
        }

        // Seeing the payment again lifts the barrier; it is then replaced.
        // BDK timestamps in seconds: a sighting must postdate the eviction.
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        await fixture.exposeBroadcasts(true);
        completed(await sync.execute(descriptor));
        expect(await gate.check(descriptor.key), BitcoinSpendStatus.ready);
        final cId = c.computeTxid().toString();
        final dId = d.computeTxid().toString();
        final rival = bdk.ElectrumClient(
          url: fixture.url,
          socks5: null,
          timeout: 5,
          retry: 0,
          validateDomain: false,
        );
        addTearDown(rival.dispose);
        final replacing = await gate.acquire(descriptor.key);
        try {
          await fixture.dropBroadcasts();
          await fixture.exposeBroadcasts(true);
          expect(rival.transactionBroadcast(tx: c).toString(), cId);
          expect(
            (replacing as BitcoinSpendAdmission).accepted(cId).durable,
            isTrue,
          );
        } finally {
          if (replacing case final BitcoinSpendAdmission lease) lease.close();
        }
        expect(await gate.check(descriptor.key), BitcoinSpendStatus.pending);
        // A tracked replacement seen in the pass settles the payment it
        // conflicts with, for that pass only: nothing is forgotten.
        completed(await sync.execute(descriptor));
        expect(await gate.check(descriptor.key), BitcoinSpendStatus.ready);
        expect(settled(aId), isTrue);
        expect(settled(cId), isTrue);
        // The conflict is no longer seen: protection of both is reinstated.
        await fixture.exposeBroadcasts(false);
        completed(await sync.execute(descriptor));
        expect(await gate.check(descriptor.key), BitcoinSpendStatus.pending);
        expect(settled(aId), isFalse);
        expect(settled(cId), isFalse);

        // A discovery scan carries no eviction delta: a confirmed conflict
        // from another device still settles both.
        expect(rival.transactionBroadcast(tx: d).toString(), dId);
        await fixture.confirmBroadcast(dId);
        completed(await sync.execute(descriptor, discover: true));
        expect(await gate.check(descriptor.key), BitcoinSpendStatus.ready);
        expect(settled(aId), isTrue);
        expect(settled(cId), isTrue);
        // Its block is reorganized away: an unconfirmed foreign conflict
        // settles nothing.
        await fixture.reorgTip();
        completed(await sync.execute(descriptor));
        expect(await gate.check(descriptor.key), BitcoinSpendStatus.pending);
        expect(settled(aId), isFalse);
      });
    }

    // A discovery pass applies the revealed-script update, then a full scan;
    // spend evidence is computed once from the final canonical state.
    for (final scenario in [
      'revealedOnly',
      'scanOnly',
      'neither',
      'scanFails',
    ]) {
      test('discovery spend evidence: broadcast seen $scenario', () async {
        await fixture.load('S10-no-change', 0);
        completed(await sync.execute(descriptor));
        final revisions = RevisionStoreDatasource.openForeground(
          revisionStorePath(dir.path),
        );
        addTearDown(revisions.close);
        final writer = NativeWalletWriterRepository(
          revisions: revisions,
          reader: SqliteWalletRevisionReader(revisions),
          documentsDirectory: dir.path,
          catalog: SingleWalletCatalog(descriptor),
          reservedAddresses: NoReservedAddresses(),
        );
        final reader = WalletSnapshotReader(
          documentsDirectory: dir.path,
          readiness: PersistedWalletReadiness(revisions),
          requiredSchemaVersion: writerSchemaVersion,
          revisions: SqliteWalletRevisionReader(revisions),
          liquidAdmission: writer,
        );
        Future<WalletReadSnapshot<bdk.Wallet>> read() async =>
            switch (await reader.bitcoin(descriptor)) {
              Ok(:final value) => value,
              Err(:final failure) => throw StateError('$failure'),
            };
        final mnemonic = bdk.Mnemonic.fromString(mnemonic: _testMnemonic);
        final secret = bdk.DescriptorSecretKey(
          networkKind: bdk.NetworkKind.test,
          mnemonic: mnemonic,
          password: null,
        );
        addTearDown(mnemonic.dispose);
        addTearDown(secret.dispose);
        final signers = [
          for (final keychain in [
            bdk.KeychainKind.external_,
            bdk.KeychainKind.internal,
          ])
            bdk.SignersContainer.fromDescriptor(
              descriptor: bdk.Descriptor.newBip84(
                secretKey: secret,
                keychainKind: keychain,
                networkKind: bdk.NetworkKind.test,
              ),
            ),
        ];
        for (final signer in signers) {
          addTearDown(signer.dispose);
        }
        final before = await read();
        // The revealed-script step asks one history per revealed script.
        var revealedScripts = 0;
        for (final keychain in [
          bdk.KeychainKind.external_,
          bdk.KeychainKind.internal,
        ]) {
          final index = before.wallet.derivationIndex(keychain: keychain);
          revealedScripts += index == null ? 0 : index + 1;
        }
        final recipient = bdk.Script(
          rawOutputScript: Uint8List.fromList([
            0,
            20,
            ...List.filled(20, 0xab),
          ]),
        );
        addTearDown(recipient.dispose);
        final psbt = bdk.TxBuilder()
            .addRecipient(
              script: recipient,
              amount: bdk.Amount.fromSat(satoshi: 10000),
            )
            .feeAbsolute(feeAmount: bdk.Amount.fromSat(satoshi: 1000))
            .finish(wallet: before.wallet);
        addTearDown(psbt.dispose);
        expect(
          before.wallet.signWithSigners(
            psbt: psbt,
            signers: signers,
            signOptions: null,
          ),
          isTrue,
        );
        final a = psbt.extractTx();
        addTearDown(a.dispose);
        final aId = a.computeTxid().toString();
        await fixture.exposeBroadcasts(
          scenario == 'revealedOnly' || scenario == 'scanFails',
        );
        final client = bdk.ElectrumClient(
          url: fixture.url,
          socks5: null,
          timeout: 5,
          retry: 0,
          validateDomain: false,
        );
        final gate = BitcoinSpendGate(
          documentsDirectory: dir.path,
          revisions: revisions,
          catalog: SingleWalletCatalog(descriptor),
        );
        final admission =
            await gate.acquire(descriptor.key) as BitcoinSpendAdmission;
        try {
          expect(client.transactionBroadcast(tx: a).toString(), aId);
          expect(admission.accepted(aId).durable, isTrue);
        } finally {
          admission.close();
          client.dispose();
        }
        await fixture.advanceTip();
        switch (scenario) {
          case 'revealedOnly':
            await fixture.exposeBroadcastsAfterHistories(
              revealedScripts,
              false,
            );
          case 'scanOnly':
            await fixture.exposeBroadcastsAfterHistories(revealedScripts, true);
          case 'scanFails':
            await fixture.failHistoriesAfter(revealedScripts);
        }
        final result = await sync.execute(descriptor, discover: true);
        if (scenario == 'scanFails') {
          expect(result, isA<Err<SyncCompletion, TransactionSyncFailure>>());
          // The failed pass publishes no success: the writer conservatively
          // invalidates the revision, and nothing it fetched was persisted.
          final after = await read();
          expect(after.stale, isTrue);
          expect(
            after.wallet.getTx(txid: bdk.Txid.fromString(hex: aId)),
            isNull,
          );
          // The gate stays closed after the failed pass.
          expect(
            await gate.check(descriptor.key),
            BitcoinSpendStatus.unavailable,
          );
          // A later complete pass recovers.
          await fixture.failHistoriesAfter(null);
          completed(await sync.execute(descriptor, discover: true));
          expect(await gate.check(descriptor.key), BitcoinSpendStatus.ready);
          return;
        }
        completed(result);
        final after = await read();
        final canonical =
            after.wallet.getTx(txid: bdk.Txid.fromString(hex: aId)) != null;
        // An observation by either step alone must survive the other's omission.
        expect(canonical, scenario != 'neither');
        // Ready only when the final canonical state holds the payment.
        expect(
          await gate.check(descriptor.key),
          canonical ? BitcoinSpendStatus.ready : BitcoinSpendStatus.pending,
        );
        // Only synthetic booleans: no production wallet data.
        print('DISCOVERY-EVIDENCE seen=$scenario canonical=$canonical');
      });
    }

    test(
      'unchanged revealed scripts preserve revision; changed scripts advance it',
      () async {
        await fixture.load('S10-no-change', 0);
        final initial = completed(await sync.execute(descriptor));
        final unchanged = completed(await sync.execute(descriptor));
        expect(unchanged.mode, SyncMode.revealedScripts);
        expect(unchanged.revision, initial.revision);
        await fixture.load('S5-incoming-older-revealed', 1);
        final changed = completed(await sync.execute(descriptor));
        expect(changed.mode, SyncMode.revealedScripts);
        expect(
          changed.revision?.revision,
          greaterThan(initial.revision?.revision ?? 0),
        );
        final revisions = RevisionStoreDatasource.openForeground(
          revisionStorePath(dir.path),
        );
        try {
          final result = await SqliteWalletRevisionReader(
            revisions,
          ).read(descriptor.key);
          expect(
            result,
            isA<Ok<WalletRevisionState, TransactionSyncFailure>>(),
          );
          final state =
              (result as Ok<WalletRevisionState, TransactionSyncFailure>).value;
          expect(state.stamp, changed.revision);
          expect(state.syncFailed, isFalse);
        } finally {
          revisions.close();
        }
      },
    );

    test('successful sync publishes an initialized durable revision', () async {
      await fixture.load(electrumFixtureScenarios.first, 0);
      completed(await sync.execute(descriptor));
      final revisions = RevisionStoreDatasource.openForeground(
        revisionStorePath(dir.path),
      );
      try {
        final state =
            (await SqliteWalletRevisionReader(revisions).read(descriptor.key)
                    as Ok<WalletRevisionState, TransactionSyncFailure>)
                .value;
        expect(state.lifecycle, WalletLifecycle.active);
        expect(state.initializedSchema, writerSchemaVersion);
        expect(state.stamp.revision, 2);
      } finally {
        revisions.close();
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
      File(
        ElectrumCacheDatasource.pathFor(path),
      ).writeAsStringSync('bad cache');
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
      final db = sqlite3.open(ElectrumCacheDatasource.pathFor(path));
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
      final db = sqlite3.open(ElectrumCacheDatasource.pathFor(path));
      db.execute('UPDATE parent_transaction SET raw = ?', [
        Uint8List.fromList([1, 2, 3]),
      ]);
      db.dispose();

      _scan(fixture, path, cached: true);

      // The bad row was dropped by the prefill and fetched again.
      expect(storedTxids(), {phase.ids['P']});
      final check = sqlite3.open(ElectrumCacheDatasource.pathFor(path));
      addTearDown(check.dispose);
      final raw = check.select('SELECT raw FROM parent_transaction').single;
      expect((raw['raw'] as Uint8List).length, greaterThan(3));
    });

    test('an unreadable sidecar is rebuilt', () {
      File(
        ElectrumCacheDatasource.pathFor(path),
      ).writeAsStringSync('not sqlite');

      final cache = ElectrumCacheDatasource.open(path);
      addTearDown(() => cache?.close());

      expect(cache, isNotNull);
      expect(cache?.rebuilt, isTrue);
      expect(storedTxids(), isEmpty);
    });

    test('a readable sidecar is not reported as rebuilt', () {
      final cache = ElectrumCacheDatasource.open(path);
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
        ElectrumCacheDatasource.describe(
          opened: true,
          rebuilt: false,
          prefill: prefill,
          parents: (stored: 4, failed: false),
        ),
        'cache=ok prefilled_txs=3 prefilled_parents=2 anchors=1 '
        'dropped_parents=0 stored_parents=4',
      );
      expect(
        ElectrumCacheDatasource.describe(opened: false, rebuilt: false),
        startsWith('cache=unavailable '),
      );
      expect(
        ElectrumCacheDatasource.describe(
          opened: true,
          rebuilt: true,
          prefill: prefill,
        ),
        startsWith('cache=rebuilt '),
      );
      expect(
        ElectrumCacheDatasource.describe(
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
      expect(File(ElectrumCacheDatasource.pathFor(path)).existsSync(), isTrue);

      ElectrumCacheDatasource.delete(path);

      expect(File(ElectrumCacheDatasource.pathFor(path)).existsSync(), isFalse);
    });
  });
}

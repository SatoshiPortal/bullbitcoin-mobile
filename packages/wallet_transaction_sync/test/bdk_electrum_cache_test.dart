import 'dart:io';
import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wallet_transaction_sync/bdk_electrum_cache.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

import 'support/electrum_fixture.dart';
import 'support/fakes.dart';

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
  tearDownAll(() => fixture.close());

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
      expect(storedTxids(), isEmpty);
    });

    test('delete removes the sidecar', () async {
      await fixture.load('S10-no-change', 0);
      _scan(fixture, path, cached: true);
      expect(File(BdkElectrumCache.pathFor(path)).existsSync(), isTrue);

      BdkElectrumCache.delete(path);

      expect(File(BdkElectrumCache.pathFor(path)).existsSync(), isFalse);
    });
  });

  group('package source', () {
    late Directory dir;
    late String path;
    late WalletSourceRegistration registration;
    late WalletTransactionSyncFacade facade;
    const key = WalletNetworkKey('cache-test', 'bitcoin', 'testnet');

    setUp(() {
      dir = Directory.systemTemp.createTempSync('wts_cache_source_');
      path = '${dir.path}/w.sqlite';
      final (external, internal) = _descriptors();
      registration = WalletSourceRegistration.withFingerprint(
        key: key,
        sourceKind: 'bdk_electrum',
        configuration: BdkElectrumConfiguration(
          externalPublicDescriptor: external,
          internalPublicDescriptor: internal,
          isTestnet: true,
          electrumUrls: [fixture.url],
          stopGap: 20,
          validateDomain: false,
          databaseFilePath: path,
          socks5: null,
          timeout: 5,
          retry: 0,
        ),
      );
      facade = WalletTransactionSyncFacade.bdkElectrum(
        metadata: RecordingMetadata(),
        coordinator: InMemoryWalletSourceOperationCoordinator(),
      );
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('a second discovery downloads no known transaction', () async {
      await fixture.load('S10-no-change', 0);
      okValue(
        await facade.discoverWalletHistory(
          DiscoverWalletHistoryRequest(registration),
        ),
      );
      await fixture.requests();

      final outcome = okValue(
        await facade.discoverWalletHistory(
          DiscoverWalletHistoryRequest(registration),
        ),
      );

      final requests = await fixture.requests();
      expect(outcome.snapshot.transactions, hasLength(1));
      expect(requests.counts['blockchain.transaction.get'], isNull);
      expect(requests.counts['blockchain.transaction.get_merkle'], isNull);
    });

    test(
      'a routine sync of a never synced wallet discovers its history',
      () async {
        final phase = await fixture.load('S10-no-change', 0);

        final outcome = okValue(
          await facade.synchronizeWallet(
            SynchronizeWalletRequest(registration),
          ),
        );

        expect(
          outcome.snapshot.transactions.map((transaction) => transaction.txid),
          contains(phase.ids['T1']),
        );
      },
    );

    test('a sync that cannot persist reports a storage failure', () async {
      await fixture.load('S5-incoming-older-revealed', 0);
      okValue(
        await facade.discoverWalletHistory(
          DiscoverWalletHistoryRequest(registration),
        ),
      );
      await fixture.load('S5-incoming-older-revealed', 1);
      final database = File(path);
      await Process.run('chmod', ['0444', database.path]);
      addTearDown(() => Process.run('chmod', ['0644', database.path]));

      final failure = errFailure(
        await facade.discoverWalletHistory(
          DiscoverWalletHistoryRequest(registration),
        ),
      );

      expect(failure, isA<SourceStorageFailure>());
    });

    test('deleting the wallet removes its cache', () async {
      await fixture.load('S10-no-change', 0);
      okValue(
        await facade.discoverWalletHistory(
          DiscoverWalletHistoryRequest(registration),
        ),
      );
      expect(File(BdkElectrumCache.pathFor(path)).existsSync(), isTrue);

      okValue(await facade.deleteWallet(key));

      expect(File(BdkElectrumCache.pathFor(path)).existsSync(), isFalse);
    });
  });
}

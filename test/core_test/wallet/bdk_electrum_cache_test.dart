import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/data/datasources/bdk_electrum_cache.dart';
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
    open.wallet.persist(persister: open.persister);
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
          cached.requests.counts['blockchain.transaction.get'] ?? 0,
          lessThanOrEqualTo(
            uncached.requests.counts['blockchain.transaction.get'] ?? 0,
          ),
        );
        expect(
          cached.requests.fetchedTxids.length,
          lessThan(uncached.requests.fetchedTxids.length),
        );
      });
    }
  });

  test('an unchanged wallet syncs without downloading transactions', () async {
    final uncached = await _run(fixture, 'S10-no-change', cached: false);
    final cached = await _run(fixture, 'S10-no-change', cached: true);

    expect(
      uncached.requests.counts['blockchain.transaction.get'],
      greaterThan(0),
    );
    expect(
      uncached.requests.counts['blockchain.transaction.get_merkle'],
      greaterThan(0),
    );
    expect(cached.requests.counts['blockchain.transaction.get'], isNull);
    expect(cached.requests.counts['blockchain.transaction.get_merkle'], isNull);
  });

  test(
    'an existing wallet warms its historical parents on the first cached scan',
    () async {
      final dir = Directory.systemTemp.createTempSync('wts_existing_');
      try {
        final reference = '${dir.path}/reference.sqlite';
        final cached = '${dir.path}/cached.sqlite';
        final phase = await fixture.load('S10-no-change', 0);
        _scan(fixture, reference, cached: false);
        _scan(fixture, cached, cached: false);
        await fixture.requests();
        _scan(fixture, reference, cached: false);
        final baseline = await fixture.requests();
        _scan(fixture, cached, cached: true);
        final actual = await fixture.requests();
        expect(baseline.fetchedTxids, {phase.ids['T1'], phase.ids['P']});
        expect(actual.fetchedTxids, {phase.ids['P']});
        expect(baseline.counts['blockchain.transaction.get'], 2);
        expect(actual.counts['blockchain.transaction.get'], 1);
        expect(baseline.counts['blockchain.transaction.get_merkle'], 1);
        expect(actual.counts['blockchain.transaction.get_merkle'], isNull);
        expect(actual.scriptHashes, baseline.scriptHashes);
        final db = sqlite3.open(BdkElectrumCache.pathFor(cached));
        try {
          expect(
            db.select('SELECT txid FROM parent_transaction').single['txid'],
            phase.ids['P'],
          );
        } finally {
          db.dispose();
        }
        _scan(fixture, cached, cached: true);
        final warm = await fixture.requests();
        expect(warm.scriptHashes, baseline.scriptHashes);
        expect(warm.counts['blockchain.transaction.get'], isNull);
        expect(warm.counts['blockchain.transaction.get_merkle'], isNull);
        final wallet = _Wallet.open(cached);
        try {
          expect(_observe(wallet.wallet, phase.ids), phase.truth);
          expect(wallet.wallet.balance().total.toSat(), 100000);
        } finally {
          wallet.close();
        }
      } finally {
        dir.deleteSync(recursive: true);
      }
    },
  );

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

      expect(storedTxids(), {phase.ids['P']});
      final repaired = sqlite3.open(BdkElectrumCache.pathFor(path));
      try {
        final raw = repaired.select('SELECT raw FROM parent_transaction');
        expect(raw.single['raw'], isNot([1, 2, 3]));
      } finally {
        repaired.dispose();
      }
    });

    test('locked sidecar is never replaced', () {
      final first = BdkElectrumCache.open(path);
      expect(first, isNotNull);
      first?.close();
      final sidecar = BdkElectrumCache.pathFor(path);
      final db = sqlite3.open(sidecar);
      db.execute('BEGIN EXCLUSIVE');
      try {
        final before = File(sidecar).readAsBytesSync();
        expect(BdkElectrumCache.open(path), isNull);
        expect(File(sidecar).readAsBytesSync(), before);
      } finally {
        db.execute('ROLLBACK');
        db.dispose();
      }
    });

    test('unreadable sidecar is preserved', () {
      final file = File(BdkElectrumCache.pathFor(path));
      file.writeAsBytesSync([1, 2, 3, 4]);
      expect(BdkElectrumCache.open(path), isNull);
      expect(file.readAsBytesSync(), [1, 2, 3, 4]);
    });
  });
}

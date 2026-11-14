import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync/src/data/datasources/freeze_store_datasource.dart';
import 'package:sync/src/data/freeze_authority.dart';
import 'package:sync/src/data/native_store_paths.dart';
import 'package:sync/src/data/wallet_projections.dart';
import 'package:sync/src/data/write/writer_stores.dart';
import 'package:sync/src/public/sync.dart' show walletOver;
import 'package:sync/sync.dart';

import 'support/freezes.dart';
import 'support/projection_fakes.dart';

void main() {
  late Directory dir;
  late String path;
  final authorities = <FreezeAuthority>[];

  setUp(() {
    dir = Directory.systemTemp.createTempSync('freezes-');
    path = freezeStorePath(dir.path);
  });
  tearDown(() async {
    for (final authority in authorities) {
      await authority.close();
    }
    authorities.clear();
    dir.deleteSync(recursive: true);
  });

  FreezeAuthority open(LegacyFreezes legacy) {
    final authority = FreezeAuthority(path: path, legacy: legacy);
    authorities.add(authority);
    return authority;
  }

  Outpoint outpoint(String c, int vout) => (txId: c * 64, vout: vout);
  FrozenOutpoint row(String c, int vout, String origin) =>
      FrozenOutpoint(outpoint(c, vout), origin: origin);

  T ok<T>(Result<T, SyncFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => fail('Unexpected ${failure.logCode}'),
  };

  SyncFailure err<T>(Result<T, SyncFailure> result) => switch (result) {
    Ok() => fail('Expected a failure'),
    Err(:final failure) => failure,
  };

  bool marked() {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      return db
          .select("SELECT 1 FROM meta WHERE key = 'legacy_import'")
          .isNotEmpty;
    } finally {
      db.dispose();
    }
  }

  File witness() => File(FreezeStoreDatasource.witnessPath(path));

  group('import', () {
    test('copies every row, empty and multiple origins included', () async {
      final legacy = LegacyFreezes([
        row('a', 0, 'wpkh([0f36572d/84h/1h/0h])'),
        // A second wallet froze the same outpoint.
        row('a', 0, 'tr([0f36572d/86h/1h/0h])'),
        // BIP329 import without a parseable origin.
        row('b', 1, ''),
        // A wallet deleted since: its freeze stays.
        row('c', 2, 'wpkh([deadbeef/84h/0h/0h])'),
      ]);
      final authority = open(legacy);

      final read = ok(await authority.read());

      expect(read.toSet(), legacy.rows.toSet());
      expect(read, hasLength(4));
      expect(marked(), isTrue);
      expect(witness().existsSync(), isTrue);
      expect(ok(await authority.forbiddenInputs()), {
        outpoint('a', 0),
        outpoint('b', 1),
        outpoint('c', 2),
      });
    });

    test('a fresh install imports an empty table and is complete', () async {
      final authority = open(LegacyFreezes());

      expect(ok(await authority.read()), isEmpty);
      expect(marked(), isTrue);
      expect(witness().existsSync(), isTrue);
    });

    test('runs once: later opens never read the app table again', () async {
      final legacy = LegacyFreezes([row('a', 0, 'w')]);
      ok(await open(legacy).read());
      legacy.rows = [row('z', 9, 'w')];

      final reopened = open(legacy);

      expect(ok(await reopened.read()), [row('a', 0, 'w')]);
      expect(legacy.reads, 1);
    });

    test('an unreadable app table is not an empty one', () async {
      final legacy = LegacyFreezes([row('a', 0, 'w')])
        ..failure = const SyncStorageFailure();
      final authority = open(legacy);

      expect(
        err(await authority.read()),
        isA<SyncFreezeImportRequiredFailure>(),
      );
      expect(
        err(await authority.forbiddenInputs()),
        isA<SyncFreezeImportRequiredFailure>(),
      );
      expect(
        err(await authority.freeze([row('b', 1, 'w')])),
        isA<SyncFreezeImportRequiredFailure>(),
      );
      expect(
        err(await authority.unfreeze([outpoint('a', 0)])),
        isA<SyncFreezeImportRequiredFailure>(),
      );
      expect(authority.snapshot, isNull);
      expect(authority.failure, isA<SyncFreezeImportRequiredFailure>());
      expect(witness().existsSync(), isFalse);
      expect(File(path).existsSync(), isFalse);

      // The next use retries.
      legacy.failure = null;
      expect(ok(await authority.read()), [row('a', 0, 'w')]);
      expect(authority.snapshot?.outpoints, {outpoint('a', 0)});
    });

    test(
      'a crash between the commit and the witness replays the import',
      () async {
        final legacy = LegacyFreezes([row('a', 0, 'w'), row('b', 1, '')]);
        // The witness cannot be written: the rows and the marker commit,
        // then the import stops, as a crash right after the commit would.
        Directory(witness().path).createSync(recursive: true);
        final authority = open(legacy);

        expect(
          err(await authority.read()),
          isA<SyncFreezeImportRequiredFailure>(),
        );
        expect(marked(), isTrue);
        // Nothing is admitted before the witness.
        expect(
          err(await authority.freeze([row('c', 2, 'w')])),
          isA<SyncFreezeImportRequiredFailure>(),
        );
        expect(
          err(await authority.unfreeze([outpoint('a', 0)])),
          isA<SyncFreezeImportRequiredFailure>(),
        );

        Directory(witness().path).deleteSync();
        final restarted = open(legacy);

        expect(ok(await restarted.read()).toSet(), legacy.rows.toSet());
        expect(witness().existsSync(), isTrue);
        // Each refused use retried the import; the restart replayed it once.
        expect(legacy.reads, 4);
      },
    );

    test('a replay refuses rows that differ from the committed ones', () async {
      final legacy = LegacyFreezes([row('a', 0, 'w')]);
      Directory(witness().path).createSync(recursive: true);
      err(await open(legacy).read());
      Directory(witness().path).deleteSync();
      legacy.rows = [row('a', 0, 'w'), row('b', 1, 'w')];

      final restarted = open(legacy);

      expect(
        err(await restarted.read()),
        isA<SyncFreezeImportRequiredFailure>(),
      );
      expect(witness().existsSync(), isFalse);
    });
  });

  group('after the switch', () {
    Future<void> switched([List<FrozenOutpoint> rows = const []]) async {
      final authority = open(LegacyFreezes(rows));
      ok(await authority.read());
      await authority.close();
    }

    test(
      'a deleted store is refused, never recreated nor reimported',
      () async {
        await switched([row('a', 0, 'w')]);
        File(path).deleteSync();
        final legacy = LegacyFreezes([row('a', 0, 'w')]);
        final authority = open(legacy);

        expect(err(await authority.read()), isA<SyncFreezeStoreLostFailure>());
        expect(
          err(await authority.forbiddenInputs()),
          isA<SyncFreezeStoreLostFailure>(),
        );
        expect(
          err(await authority.freeze([row('b', 1, 'w')])),
          isA<SyncFreezeStoreLostFailure>(),
        );
        // Explicit recovery checks again; it does not recreate anything.
        expect(
          err(await authority.recover()),
          isA<SyncFreezeStoreLostFailure>(),
        );
        expect(legacy.reads, 0);
        expect(File(path).existsSync(), isFalse);
        expect(witness().existsSync(), isTrue);
      },
    );

    test('recovery succeeds once the store is back whole', () async {
      await switched([row('a', 0, 'w')]);
      File(path).renameSync('$path.saved');
      final authority = open(LegacyFreezes());
      expect(err(await authority.read()), isA<SyncFreezeStoreLostFailure>());

      File('$path.saved').renameSync(path);
      // Lost is kept until the explicit recovery.
      expect(err(await authority.read()), isA<SyncFreezeStoreLostFailure>());
      ok(await authority.recover());

      expect(ok(await authority.read()), [row('a', 0, 'w')]);
    });

    test('an unreadable store is refused', () async {
      await switched();
      File(path).writeAsStringSync('not a database');

      expect(
        err(await open(LegacyFreezes()).read()),
        isA<SyncFreezeStoreLostFailure>(),
      );
      expect(File(path).readAsStringSync(), 'not a database');
    });

    test('a store without its import marker is refused', () async {
      await switched([row('a', 0, 'w')]);
      final db = sqlite3.open(path);
      db.execute("DELETE FROM meta WHERE key = 'legacy_import'");
      db.dispose();
      final legacy = LegacyFreezes([row('a', 0, 'w')]);

      expect(err(await open(legacy).read()), isA<SyncFreezeStoreLostFailure>());
      expect(legacy.reads, 0);
    });

    test('an unfreeze is not undone by a later open', () async {
      final legacy = LegacyFreezes([row('a', 0, 'w'), row('a', 0, '')]);
      final authority = open(legacy);
      ok(await authority.unfreeze([outpoint('a', 0)]));
      await authority.close();

      // The app table still holds both rows.
      final reopened = open(legacy);

      expect(ok(await reopened.read()), isEmpty);
      expect(ok(await reopened.forbiddenInputs()), isEmpty);
      expect(legacy.reads, 1);
    });

    test('unfreeze removes every attribution of the outpoint', () async {
      final authority = open(
        LegacyFreezes([
          row('a', 0, 'one'),
          row('a', 0, 'two'),
          row('b', 0, ''),
        ]),
      );
      ok(await authority.unfreeze([outpoint('a', 0)]));

      expect(ok(await authority.read()), [row('b', 0, '')]);
    });

    test('freezes without a known wallet keep their origin', () async {
      final authority = open(LegacyFreezes());
      final first = ok(await authority.freeze([row('a', 0, '')]));
      final second = ok(await authority.freeze([row('b', 1, 'unknown')]));
      await authority.close();

      final reopened = open(LegacyFreezes());

      expect(second.value, greaterThan(first.value));
      expect(ok(await reopened.read()).toSet(), {
        row('a', 0, ''),
        row('b', 1, 'unknown'),
      });
    });

    test('a guard holds the store: another connection cannot freeze', () async {
      final authority = open(LegacyFreezes());
      ok(await authority.read());
      final other = open(LegacyFreezes());
      ok(await other.read());
      final release = Completer<void>();
      final guarded = authority.guard((forbidden) => release.future);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // busy_timeout expires while the guard holds the write lock.
      expect(
        err(await other.freeze([row('a', 0, 'w')])),
        isA<SyncStorageFailure>(),
      );
      release.complete();
      ok(await guarded);
      ok(await other.freeze([row('a', 0, 'w')]));
    });
  });

  test('background stores never create the freeze store', () async {
    final foreground = openForeground(
      documentsDirectory: dir.path,
      catalog: const _NoCatalog(),
      reservedAddresses: const _NoReserved(),
      legacyFreezes: LegacyFreezes(),
    );
    await foreground.close();

    final background = openExisting(dir.path);
    await background.close();

    expect(File(path).existsSync(), isFalse);
    expect(witness().existsSync(), isFalse);
  });

  group('wallet coins', () {
    final key = WalletKey(id: 'coins', network: LiquidNetwork.testnet);
    late ScriptedRevisions revisions;
    late WalletProjections projections;

    LiquidCoin coin(String c, int vout) => LiquidCoin(
      outpoint: outpoint(c, vout),
      amountSat: BigInt.from(1000),
      scriptPubkey: '00',
      standardAddress: 's',
      confidentialAddress: 'c',
      blockHeight: 1,
    );

    WalletProjections projectionsOver(FreezePolicy freezes) {
      revisions = ScriptedRevisions(key);
      return projections = WalletProjections(
        revisions: revisions,
        changes: revisions.changes.stream,
        source: _CoinSource([coin('a', 0), coin('b', 1)]),
        freezes: freezes,
      );
    }

    tearDown(() => projections.close());

    test('coins are unavailable, never unfrozen, until the import', () async {
      final legacy = LegacyFreezes([row('a', 0, 'coins')])
        ..failure = const SyncStorageFailure();
      final authority = open(legacy);
      final wallet = walletOver(projectionsOver(authority), key, 0);
      ok(await wallet.load());
      final seen = <WalletCoins>[];
      final subscription = wallet.coins.watch().listen(seen.add);
      await pumpEventQueue();

      expect(wallet.coins.now.status, ValueStatus.unavailable);
      expect(wallet.coins.now.data, isNull);
      expect(wallet.coins.now.failure, isA<SyncFreezeImportRequiredFailure>());
      expect(
        err(await wallet.coins.freeze(outpoint('b', 1))),
        isA<SyncFreezeImportRequiredFailure>(),
      );

      legacy.failure = null;
      ok(await authority.read());
      await pumpEventQueue();

      final coins = wallet.coins.now.data;
      expect(wallet.coins.now.status, ValueStatus.ready);
      expect(
        [for (final c in coins ?? CoinList(const [])) c.frozen],
        [true, false],
      );
      expect(seen.last.data, coins);
      await subscription.cancel();
    });

    test('freeze and unfreeze republish the coins without a reload', () async {
      final authority = open(LegacyFreezes());
      final source = _CoinSource([coin('a', 0), coin('b', 1)]);
      revisions = ScriptedRevisions(key);
      projections = WalletProjections(
        revisions: revisions,
        changes: revisions.changes.stream,
        source: source,
        freezes: authority,
      );
      ok(await authority.read());
      final wallet = walletOver(projections, key, 0);
      ok(await wallet.load());
      final seen = <List<bool>>[];
      final subscription = wallet.coins.watch().listen(
        (value) => seen.add([
          for (final c in value.data ?? CoinList(const [])) c.frozen,
        ]),
      );
      await pumpEventQueue();

      ok(await wallet.coins.freeze(outpoint('b', 1)));
      await pumpEventQueue();
      ok(await wallet.coins.unfreeze(outpoint('b', 1)));
      await pumpEventQueue();

      expect(seen, [
        [false, false],
        [false, true],
        [false, false],
      ]);
      expect(source.loads, 1);
      expect(ok(await authority.read()), isEmpty);
      await subscription.cancel();
    });

    test('coins carry their freezes as soon as a load returns', () async {
      final authority = open(LegacyFreezes([row('a', 0, 'coins')]));
      final wallet = walletOver(projectionsOver(authority), key, 0);

      ok(await wallet.load());

      expect(wallet.coins.now.status, ValueStatus.ready);
      expect(
        [for (final c in wallet.coins.now.data ?? CoinList(const [])) c.frozen],
        [true, false],
      );
    });

    test('a wallet freeze is attributed to the wallet', () async {
      final authority = open(LegacyFreezes());
      final wallet = walletOver(projectionsOver(authority), key, 0);
      ok(await wallet.load());

      ok(await wallet.coins.freeze(outpoint('a', 0)));

      expect(ok(await authority.read()), [row('a', 0, 'coins')]);
      final unspent = ok(await wallet.unspent());
      expect([for (final c in unspent) c.frozen], [true, false]);
    });

    test('a handle ended by a re-import cannot freeze', () async {
      final authority = open(LegacyFreezes());
      final wallet = walletOver(projectionsOver(authority), key, 0);
      revisions.reimport();

      expect(
        err(await wallet.coins.freeze(outpoint('a', 0))),
        isA<SyncNotFoundFailure>(),
      );
      expect(ok(await authority.read()), isEmpty);
    });
  });
}

final class _CoinSource implements FrameSource {
  final List<Coin> coins;
  int loads = 0;

  _CoinSource(this.coins);

  @override
  Future<Result<LoadedFrame, SyncFailure>> load(
    WalletKey key,
    WalletFrame? current,
  ) async {
    loads++;
    final frame = ScriptedSource.frame(
      WalletRevision(key: key, generation: 0, revision: 0),
      stale: false,
    );
    return Ok((
      frame: WalletFrame(
        WalletFrameData(
          revision: frame.revision,
          balances: frame.balances,
          coins: CoinList(coins),
          transactions: frame.transactions,
          addresses: frame.addresses,
          ownership: frame.ownership,
        ),
        stale: false,
      ),
      admitted: true,
    ));
  }

  @override
  Future<Result<DerivedAddress, SyncFailure>> derive(
    WalletKey key,
    Keychain keychain,
    int index,
  ) async => const Err(SyncNotFoundFailure());
}

final class _NoCatalog implements WalletCatalogPort {
  const _NoCatalog();

  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async => const Err(SyncNotFoundFailure());

  @override
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list() async =>
      const Ok([]);
}

final class _NoReserved implements ReservedAddressPort {
  const _NoReserved();

  @override
  Future<Result<bool, SyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) async => const Ok(false);
}

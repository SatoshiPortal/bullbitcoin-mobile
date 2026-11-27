import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/src/data/freeze_authority.dart';
import 'package:sync/src/data/wallet_projections.dart';
import 'package:sync/src/public/sync.dart' show walletOver;
import 'package:sync/sync.dart';
import 'package:sync/testing.dart' show MemoryFreezeStore;

import 'support/projection_fakes.dart';

void main() {
  final authorities = <FreezeAuthority>[];

  tearDown(() async {
    for (final authority in authorities) {
      await authority.close();
    }
    authorities.clear();
  });

  FreezeAuthority open(FreezeStorePort store) {
    final authority = FreezeAuthority(store);
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

  group('store', () {
    test('a failing store is never an empty one', () async {
      final store = MemoryFreezeStore([row('a', 0, 'w')])
        ..failure = const SyncStorageFailure();
      final authority = open(store);

      expect(err(await authority.read()), isA<SyncStorageFailure>());
      expect(err(await authority.forbiddenInputs()), isA<SyncStorageFailure>());
      expect(
        err(await authority.freeze([row('b', 1, 'w')])),
        isA<SyncStorageFailure>(),
      );
      expect(
        err(await authority.unfreeze([outpoint('a', 0)])),
        isA<SyncStorageFailure>(),
      );
      expect(
        err(await authority.guard((forbidden) => fail('ran'))),
        isA<SyncStorageFailure>(),
      );
      expect(authority.snapshot, isNull);
      expect(authority.failure, isA<SyncStorageFailure>());
      expect(store.rows, {row('a', 0, 'w')});

      // The next use reads again.
      store.failure = null;
      expect(ok(await authority.read()), [row('a', 0, 'w')]);
      expect(authority.snapshot?.outpoints, {outpoint('a', 0)});
      expect(authority.failure, isNull);
    });

    test('a failed read keeps the freezes read before', () async {
      final store = MemoryFreezeStore([row('a', 0, 'w')]);
      final authority = open(store);
      ok(await authority.read());

      store.failure = const SyncStorageFailure();

      expect(err(await authority.read()), isA<SyncStorageFailure>());
      expect(authority.snapshot?.outpoints, {outpoint('a', 0)});
    });

    test('reads every row, empty and multiple origins included', () async {
      final rows = [
        row('a', 0, 'wpkh([0f36572d/84h/1h/0h])'),
        // A second wallet froze the same outpoint.
        row('a', 0, 'tr([0f36572d/86h/1h/0h])'),
        // BIP329 import without a known wallet.
        row('b', 1, ''),
      ];
      final authority = open(MemoryFreezeStore(rows));

      expect(ok(await authority.read()).toSet(), rows.toSet());
      expect(ok(await authority.forbiddenInputs()), {
        outpoint('a', 0),
        outpoint('b', 1),
      });
    });

    test('unfreeze lifts every attribution of the outpoint', () async {
      final store = MemoryFreezeStore([
        row('a', 0, 'one'),
        row('a', 0, ''),
        row('b', 0, 'one'),
      ]);
      final authority = open(store);

      ok(await authority.unfreeze([outpoint('a', 0)]));

      expect(store.rows, {row('b', 0, 'one')});
      expect(authority.snapshot?.outpoints, {outpoint('b', 0)});
    });

    test('each committed change is a new policy revision', () async {
      final authority = open(MemoryFreezeStore());

      final first = ok(await authority.freeze([row('a', 0, '')]));
      final second = ok(await authority.freeze([row('b', 1, 'unknown')]));
      final third = ok(await authority.unfreeze([outpoint('a', 0)]));

      expect(second.value, greaterThan(first.value));
      expect(third.value, greaterThan(second.value));
      expect(authority.snapshot?.revision, third);
    });

    test('a guard holds back freezes until its body returns', () async {
      final store = MemoryFreezeStore([row('a', 0, 'w')]);
      final authority = open(store);
      final release = Completer<void>();
      final guarded = authority.guard((forbidden) async {
        await release.future;
        return forbidden;
      });
      var committed = false;
      final freezing = authority
          .freeze([row('b', 1, 'w')])
          .whenComplete(() => committed = true);
      await pumpEventQueue();

      expect(committed, isFalse);
      release.complete();
      expect(ok(await guarded), {outpoint('a', 0)});
      ok(await freezing);
      expect(store.rows, {row('a', 0, 'w'), row('b', 1, 'w')});
    });
    test('a failed read never runs the guard body', () async {
      final store = MemoryFreezeStore()..failure = const SyncStorageFailure();
      final authority = open(store);
      var ran = false;

      final guarded = await authority.guard((forbidden) => ran = true);

      expect(err(guarded), isA<SyncStorageFailure>());
      expect(ran, isFalse);
    });

    test('an exception of the guard body propagates; freezes go on', () async {
      final store = MemoryFreezeStore();
      final authority = open(store);

      await expectLater(
        authority.guard<void>((forbidden) => throw const FormatException('x')),
        throwsA(isA<FormatException>()),
      );

      ok(await authority.freeze([row('a', 0, 'w')]));
      expect(store.rows, {row('a', 0, 'w')});
    });
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

    test('coins are unavailable, never unfrozen, until a read', () async {
      final store = MemoryFreezeStore([row('a', 0, 'coins')])
        ..failure = const SyncStorageFailure();
      final authority = open(store);
      final wallet = walletOver(projectionsOver(authority), key, 0);
      ok(await wallet.load());
      final seen = <WalletCoins>[];
      final subscription = wallet.coins.watch().listen(seen.add);
      await pumpEventQueue();

      expect(wallet.coins.now.status, ValueStatus.unavailable);
      expect(wallet.coins.now.data, isNull);
      expect(wallet.coins.now.failure, isA<SyncStorageFailure>());
      expect(
        err(await wallet.coins.freeze(outpoint('b', 1))),
        isA<SyncStorageFailure>(),
      );

      store.failure = null;
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

    test('a committed freeze with failed readback invalidates coins', () async {
      final store = _FailedReadbackStore();
      final authority = open(store);
      final wallet = walletOver(projectionsOver(authority), key, 0);
      ok(await wallet.load());
      ok(await authority.read());
      final subscription = wallet.coins.watch().listen((_) {});
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(wallet.coins.now.status, ValueStatus.ready);

      final point = outpoint('b', 1);
      expect(await wallet.coins.freeze(point), isA<Ok>());
      expect(store.committed, [FrozenOutpoint(point, origin: key.id)]);
      await pumpEventQueue();
      expect(wallet.coins.now.status, ValueStatus.unavailable);
      expect(wallet.coins.now.failure, isA<SyncStorageFailure>());
    });

    test('freeze and unfreeze republish the coins without a reload', () async {
      final authority = open(MemoryFreezeStore());
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
      final authority = open(MemoryFreezeStore([row('a', 0, 'coins')]));
      final wallet = walletOver(projectionsOver(authority), key, 0);

      ok(await wallet.load());

      expect(wallet.coins.now.status, ValueStatus.ready);
      expect(
        [for (final c in wallet.coins.now.data ?? CoinList(const [])) c.frozen],
        [true, false],
      );
    });

    test('a wallet freeze is attributed to the wallet', () async {
      final authority = open(MemoryFreezeStore());
      final wallet = walletOver(projectionsOver(authority), key, 0);
      ok(await wallet.load());

      ok(await wallet.coins.freeze(outpoint('a', 0)));

      expect(ok(await authority.read()), [row('a', 0, 'coins')]);
      final unspent = ok(await wallet.unspent());
      expect([for (final c in unspent) c.frozen], [true, false]);
    });

    test('a handle ended by a re-import cannot freeze', () async {
      final authority = open(MemoryFreezeStore());
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

final class _FailedReadbackStore implements FreezeStorePort {
  final committed = <FrozenOutpoint>[];

  @override
  Future<Result<List<FrozenOutpoint>, SyncFailure>> readAll() async =>
      committed.isEmpty ? const Ok([]) : const Err(SyncStorageFailure());

  @override
  Future<Result<void, SyncFailure>> freeze(List<FrozenOutpoint> rows) async {
    committed.addAll(rows);
    return const Ok(null);
  }

  @override
  Future<Result<void, SyncFailure>> unfreeze(List<Outpoint> outpoints) async =>
      fail('Unexpected unfreeze');
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

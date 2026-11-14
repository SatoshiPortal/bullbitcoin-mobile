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

  FreezeAuthority open(MemoryFreezeStore store) {
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

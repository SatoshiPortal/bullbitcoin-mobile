import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/src/data/wallet_projections.dart';
import 'package:sync/src/public/sync.dart' show walletOver;
import 'package:sync/sync.dart';

import 'support/projection_fakes.dart';
import 'package:sync/src/testing/test_wallets.dart' show MemoryFreezes;

/// Exact queries (ownership, unspent) decide protocol steps: they must answer
/// with the committed revision proven at the end of the load, never with a
/// cache the reader served because a writer held the wallet.
void main() {
  final key = WalletKey(id: 'exact', network: BitcoinNetwork.testnet);
  late ScriptedRevisions revisions;
  late ScriptedSource source;
  late WalletProjections projections;
  late Wallet wallet;

  setUp(() async {
    revisions = ScriptedRevisions(key);
    source = ScriptedSource(revisions);
    projections = WalletProjections(
      freezes: MemoryFreezes(),
      revisions: revisions,
      changes: revisions.changes.stream,
      source: source,
    );
    wallet = walletOver(projections, key, 0);
    expect(await wallet.load(), isA<Ok<WalletRevision, SyncFailure>>());
  });
  tearDown(() => projections.close());

  Matcher busy<T extends Object>() => isA<Err<T, SyncFailure>>().having(
    (err) => err.failure,
    'failure',
    isA<SyncBusyFailure>(),
  );

  test('a cache served while a writer holds the wallet is busy', () async {
    // The committed revision is still the cached one, but only the cache is
    // readable: nothing proves the writer will not commit over it.
    revisions.beginWrite();
    source.busy = true;
    expect(await wallet.ownership(), busy<OwnershipIndex>());
    expect(await wallet.unspent(), busy<CoinList>());
  });

  test(
    'a commit landing during the load is never answered by the cache',
    () async {
      // The worker commits N+1 and starts another write after the load read
      // its witness: the reader can then only serve its cached N.
      source.onLoad = () {
        revisions
          ..commit()
          ..beginWrite();
        source.busy = true;
      };
      expect(await wallet.ownership(), busy<OwnershipIndex>());
    },
  );

  test('a fresh hydration of a commit made during the load is exact', () async {
    source.onLoad = () {
      source.onLoad = null;
      revisions.commit();
    };
    final result = await wallet.ownership();
    expect(result, isA<Ok<OwnershipIndex, SyncFailure>>());
    final index = (result as Ok<OwnershipIndex, SyncFailure>).value;
    expect(index.revision.revision, 1);
    expect(index.ownsScript(Uint8List.fromList([1])), isTrue);
  });

  test('a failed sync does not make the committed revision inexact', () async {
    revisions.commit(syncFailed: true);
    final result = await wallet.ownership();
    expect(result, isA<Ok<OwnershipIndex, SyncFailure>>());
    expect(wallet.balances.now.status, ValueStatus.stale);
  });
}

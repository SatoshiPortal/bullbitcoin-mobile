import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/src/data/wallet_projections.dart';
import 'package:sync/src/public/sync.dart' show walletOver;
import 'package:sync/sync.dart';

import 'support/projection_fakes.dart';
import 'package:sync/src/testing/test_wallets.dart' show MemoryFreezes;

/// A load whose mapping is suspended must not publish once a delete or a
/// re-import invalidated the generation it was loading.
void main() {
  final key = WalletKey(id: 'inflight', network: BitcoinNetwork.testnet);
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

  Matcher notFound<T extends Object>() => isA<Err<T, SyncFailure>>().having(
    (err) => err.failure,
    'failure',
    isA<SyncNotFoundFailure>(),
  );

  /// Starts a load of the next commit and holds it inside the mapping.
  Future<Future<Result<WalletRevision, SyncFailure>>> suspendedLoad() async {
    revisions.commit();
    source
      ..mapping = Completer<void>()
      ..mappingEntered = Completer<void>();
    final loading = wallet.load();
    await source.mappingEntered.future;
    return loading;
  }

  test('a delete observed during the mapping dominates', () async {
    final loading = await suspendedLoad();
    revisions
      ..delete()
      ..emit();
    await Future<void>.delayed(Duration.zero);
    expect(wallet.balances.now.failure, isA<SyncNotFoundFailure>());

    source.mapping?.complete();
    final result = await loading;
    final balances = wallet.balances.now;
    expect(balances.status, ValueStatus.unavailable);
    expect(balances.failure, isA<SyncNotFoundFailure>());
    expect(balances.data, isNull);
    expect(result, notFound<WalletRevision>());
  });

  test('a re-import committed during the mapping is never published to the '
      'old handle', () async {
    final loading = await suspendedLoad();
    revisions.reimport();

    source.mapping?.complete();
    final result = await loading;
    final balances = wallet.balances.now;
    expect(balances.status, ValueStatus.unavailable);
    expect(balances.failure, isA<SyncNotFoundFailure>());
    expect(result, notFound<WalletRevision>());
    expect(await wallet.ownership(), notFound<OwnershipIndex>());
  });
}

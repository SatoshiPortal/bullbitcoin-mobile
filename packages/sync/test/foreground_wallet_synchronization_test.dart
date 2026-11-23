import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';
import 'package:test/test.dart';

import 'support/connections.dart';

final class _Catalog implements WalletCatalogPort {
  final Result<PublicWalletDescriptor, SyncFailure> found;
  final requested = <WalletKey>[];

  _Catalog(this.found);

  @override
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list() async =>
      const Ok([]);

  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async {
    requested.add(key);
    return found;
  }
}

void main() {
  final key = WalletKey(id: 'wallet', network: BitcoinNetwork.regtest);

  ForegroundWalletSynchronization synchronization(
    FixtureConnections connections,
  ) => ForegroundWalletSynchronization(
    ElectrumSync(
      connections: connections,
      documentsDirectory: () async => '/nonexistent',
      readRevision: (_) async => const Err(SyncNotFoundFailure()),
    ),
  );

  for (final failure in const <SyncFailure>[
    SyncNotFoundFailure(),
    SyncInvalidCatalogFailure(),
    SyncStorageFailure(),
  ]) {
    test(
      'a catalog ${failure.runtimeType} is returned before any connection',
      () async {
        final connections = FixtureConnections(['tcp://unused:1']);
        final catalog = _Catalog(Err(failure));

        final result = await synchronization(
          connections,
        ).executeKey(key, catalog);

        expect(
          result,
          isA<Err<void, SyncFailure>>().having(
            (result) => result.failure,
            'failure',
            failure,
          ),
        );
        expect(catalog.requested, [key]);
        expect(connections.attempts, 0);
      },
    );
  }
}

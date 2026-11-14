import 'package:primitives/primitives.dart';
import 'package:test/test.dart';
import 'package:transaction_sync/src/data/datasources/spend_gate_store_datasource.dart';
import 'package:transaction_sync/src/data/native_store_paths.dart';
import 'package:transaction_sync/src/data/datasources/revision_store_datasource.dart';
import 'package:transaction_sync/src/data/sqlite_wallet_revision_reader.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:transaction_sync/write.dart';

final class FixtureConnections implements WalletConnectionPort {
  final List<String> urls;
  final String? socks5;
  int attempts = 0;
  bool routeActive = false;

  FixtureConnections(this.urls, {this.socks5});

  @override
  Future<Result<T, TransactionSyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, TransactionSyncFailure>> Function(
      WalletConnection,
    )
    operation,
    required bool Function(TransactionSyncFailure) mayRetry,
  }) async {
    routeActive = true;
    try {
      for (final url in urls) {
        attempts++;
        final result = await operation(
          WalletConnection(
            url: url,
            socks5: socks5,
            timeout: const Duration(seconds: 1),
            retry: 0,
            stopGap: 20,
            validateDomain: false,
          ),
        );
        if (result case Err(:final failure) when mayRetry(failure)) continue;
        return result;
      }
      return const Err(TransactionSyncConnectionFailure());
    } finally {
      routeActive = false;
    }
  }
}

/// An engine whose foreground already created the package stores, as the app
/// does before any pass; the stores close with the current test.
ElectrumSync foregroundSync(String root, WalletConnectionPort connections) {
  final store = RevisionStoreDatasource.openForeground(revisionStorePath(root));
  SpendGateStoreDatasource.provision(spendGateStorePath(root));
  final reader = SqliteWalletRevisionReader(store);
  addTearDown(() async {
    await reader.close();
    store.close();
  });
  return ElectrumSync(
    connections: connections,
    documentsDirectory: () async => root,
    readRevision: reader.read,
  );
}

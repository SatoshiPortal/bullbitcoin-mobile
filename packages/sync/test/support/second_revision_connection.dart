import 'package:sync/src/data/datasources/revision_store_datasource.dart';
import 'package:sync/sync.dart';

export 'package:sync/src/data/datasources/revision_store_datasource.dart'
    show WriteIntent;

/// Drives durable transitions from outside the foreground runtime in tests.
final class SecondRevisionConnection {
  final RevisionStoreDatasource _store;

  SecondRevisionConnection(String path)
    : _store = RevisionStoreDatasource.openExisting(path);

  WalletRevision? stamp(WalletKey key) => _store.record(key)?.state.stamp;

  void begin(WalletKey key, WriteIntent intent) => _store.begin(key, intent);

  WalletRevision finish(WalletKey key, {PublicWalletDescriptor? descriptor}) =>
      _store.finish(key, initializedDescriptor: descriptor).stamp;

  void close() => _store.close();
}

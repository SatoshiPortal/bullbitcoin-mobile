import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/ports/wallet_revision_reader_port.dart';
import '../domain/transaction_sync_failure.dart';
import '../domain/wallet_key.dart';
import '../domain/wallet_revision.dart';
import 'revision_store_datasource.dart';

/// Domain reads of the revision store plus this isolate's change stream. The
/// writer publishes each state after its commit; [read] publishes what it
/// finds, which bridges commits made by a worker or another isolate when the
/// caller reads again on worker return or resume.
final class SqliteWalletRevisionReader implements WalletRevisionReaderPort {
  final RevisionStoreDatasource _store;
  final _changes = StreamController<WalletRevisionState>.broadcast();
  final _published = <WalletKey, WalletRevisionState>{};

  SqliteWalletRevisionReader(this._store);

  @override
  Future<Result<WalletRevisionState, TransactionSyncFailure>> read(
    WalletKey key,
  ) async {
    try {
      final value = _store.record(key);
      if (value == null) return const Err(TransactionSyncNotFoundFailure());
      publish(value.state);
      return Ok(value.state);
    } on SqliteException catch (error) {
      return Err(
        error.resultCode == 5
            ? const TransactionSyncBusyFailure()
            : const TransactionSyncStorageFailure(),
      );
    }
  }

  /// Emits [state] unless it is the one last published for its key.
  void publish(WalletRevisionState state) {
    final previous = _published[state.stamp.key];
    if (previous?.stamp == state.stamp &&
        previous?.lifecycle == state.lifecycle &&
        previous?.initializedSchema == state.initializedSchema &&
        previous?.syncFailed == state.syncFailed) {
      return;
    }
    _published[state.stamp.key] = state;
    _changes.add(state);
  }

  Stream<WalletRevisionState> get changes => _changes.stream;

  @override
  Stream<WalletRevisionState> watch(WalletKey key) =>
      _changes.stream.where((state) => state.stamp.key == key);

  Future<void> close() => _changes.close();
}

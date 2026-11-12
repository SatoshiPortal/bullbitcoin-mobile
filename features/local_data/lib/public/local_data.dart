import 'package:bull_local_data/src/data/foreground_executor.dart';
import 'package:bull_local_data/src/data/local_database_repository_impl.dart';
import 'package:bull_local_data/src/domain/local_data_failure.dart';
import 'package:bull_local_data/src/domain/local_database.dart';
import 'package:bull_local_data/src/domain/usecases/reset_local_database_usecase.dart';
import 'package:bull_local_data/src/domain/usecases/unlock_local_databases_usecase.dart';
import 'package:bull_local_data/src/presentation/local_data_gate_cubit.dart';
import 'package:bull_local_data/src/ui/local_data_gate_screen.dart';
import 'package:bull_sqlite/bull_sqlite.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

/// The shell's entry point: opens the app's local databases encrypted before anything else uses them, and shows what to do when they cannot be opened.
///
/// Foreground only. Background work must not open these databases: this is where they are migrated to encryption and where a consented reset erases them.
abstract final class LocalData {
  /// Unlocks every local database: reads (or, only when no encrypted data exists, creates) each key through `secrets`, encrypts a database still in clear, and checks each one opens.
  ///
  /// On success the session owns the main database's executor until [LocalDataSession.close].
  @useResult
  static Future<Result<LocalDataSession, LocalDataFailure>> unlock({
    required Secrets secrets,
    required LocalDatabasePaths paths,
  }) async {
    final repository = LocalDatabaseRepositoryImpl(
      secrets: secrets,
      paths: paths,
    );
    final UnlockedDatabases unlocked;
    switch (await UnlockLocalDatabasesUsecase(repository).execute()) {
      case Ok(:final value):
        unlocked = value;
      case Err(:final failure):
        return Err(failure);
    }
    // Every open is preceded by a durable directory: a rename whose sync failed is published before anything writes to it.
    if (EncryptedSqlite.barrier(unlocked.main.path) case Err(:final failure)) {
      return Err(LocalDataUnexpectedFailure('$failure'));
    }
    return Ok(
      LocalDataSession._(foregroundExecutor(unlocked.main), unlocked.payjoin),
    );
  }

  /// Whether [failure] has a screen of its own. The others are startup errors like any other.
  static bool hasScreenFor(LocalDataFailure failure) =>
      failure is! LocalDataUnexpectedFailure;

  /// The screen for [failure]: retry, and for an unreadable database a consented reset of that database only. [onRetry] starts the app again from the unlock.
  static Widget screen({
    required LocalDataFailure failure,
    required Secrets secrets,
    required LocalDatabasePaths paths,
    required Future<void> Function() onRetry,
  }) => BlocProvider(
    // A fresh cubit for every failure shown: a retry that fails again, or moves on to the other database, must not inherit the previous screen's state.
    key: ValueKey<Object>(Object()),
    create: (_) => LocalDataGateCubit(
      failure: failure,
      reset: ResetLocalDatabaseUsecase(
        LocalDatabaseRepositoryImpl(secrets: secrets, paths: paths),
      ),
      retry: onRetry,
    ),
    child: const LocalDataGateScreen(),
  );
}

/// The unlocked local databases of one foreground run.
final class LocalDataSession {
  /// The main database's executor, keyed on every connection. Owned by the session.
  final QueryExecutor mainDatabase;
  final UnlockedDatabase _payjoin;

  LocalDataSession._(this.mainDatabase, this._payjoin);

  /// Payjoin opens its database lazily, after startup; it needs the key at that point.
  DatabaseKey get payjoinKey => _payjoin.key;

  /// Closes the main database. For a startup that fails after the unlock.
  Future<void> close() => mainDatabase.close();
}

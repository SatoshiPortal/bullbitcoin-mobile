import 'package:bull_local_data/src/domain/local_data_failure.dart';
import 'package:bull_local_data/src/domain/local_database.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Result;

abstract interface class LocalDatabaseRepository {
  /// Makes [database] openable with its key: finishes an interrupted reset, decides from the files whether a missing key may be created, encrypts a plaintext database, and checks that the key opens it.
  ///
  /// Never creates a key for a database that exists encrypted, and never deletes anything.
  @useResult
  Future<Result<UnlockedDatabase, LocalDataFailure>> unlock(
    LocalDatabase database,
  );

  /// Erases [database] and its key. Only ever called after the user consented.
  @useResult
  Future<Result<void, LocalDataFailure>> reset(LocalDatabase database);
}

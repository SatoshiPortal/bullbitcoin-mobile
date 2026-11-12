import 'package:bull_local_data/src/domain/local_data_failure.dart';
import 'package:bull_local_data/src/domain/local_database.dart';
import 'package:bull_local_data/src/domain/local_database_repository.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Erases one database the user agreed to lose, and its key. Readable databases are never reset.
class ResetLocalDatabaseUsecase {
  final LocalDatabaseRepository _repository;

  const ResetLocalDatabaseUsecase(this._repository);

  @useResult
  Future<Result<void, LocalDataFailure>> execute(LocalDatabase database) =>
      _repository.reset(database);
}

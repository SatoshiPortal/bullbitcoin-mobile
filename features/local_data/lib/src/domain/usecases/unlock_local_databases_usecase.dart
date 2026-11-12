import 'package:bull_local_data/src/domain/local_data_failure.dart';
import 'package:bull_local_data/src/domain/local_database.dart';
import 'package:bull_local_data/src/domain/local_database_repository.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

typedef UnlockedDatabases = ({UnlockedDatabase main, UnlockedDatabase payjoin});

/// Unlocks the main database, then Payjoin's, and stops at the first that cannot be opened: each failure names its own database, so a reset never reaches a readable one.
class UnlockLocalDatabasesUsecase {
  final LocalDatabaseRepository _repository;

  const UnlockLocalDatabasesUsecase(this._repository);

  @useResult
  Future<Result<UnlockedDatabases, LocalDataFailure>> execute() async {
    final UnlockedDatabase main;
    switch (await _repository.unlock(LocalDatabase.main)) {
      case Ok(:final value):
        main = value;
      case Err(:final failure):
        return Err(failure);
    }
    return switch (await _repository.unlock(LocalDatabase.payjoin)) {
      Ok(:final value) => Ok((main: main, payjoin: value)),
      Err(:final failure) => Err(failure),
    };
  }
}

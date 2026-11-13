import 'package:bull_local_data/src/domain/local_data_failure.dart';
import 'package:bull_local_data/src/domain/local_database.dart';
import 'package:bull_local_data/src/domain/local_database_repository.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

typedef UnlockedDatabases = ({
  UnlockedDatabase main,
  UnlockedDatabase payjoin,
  UnlockedDatabase recoverbull,
});

/// Unlocks main, Payjoin and RecoverBull in order, stopping at the first failure. Each failure names its own database, so a reset never reaches a readable one.
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
    final UnlockedDatabase payjoin;
    switch (await _repository.unlock(LocalDatabase.payjoin)) {
      case Ok(:final value):
        payjoin = value;
      case Err(:final failure):
        return Err(failure);
    }
    return switch (await _repository.unlock(LocalDatabase.recoverbull)) {
      Ok(:final value) => Ok((
        main: main,
        payjoin: payjoin,
        recoverbull: value,
      )),
      Err(:final failure) => Err(failure),
    };
  }
}

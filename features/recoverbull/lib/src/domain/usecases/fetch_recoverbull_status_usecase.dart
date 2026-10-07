import '../entities/recoverbull_status.dart';
import '../repositories/recoverbull_repository.dart';

final class FetchRecoverBullStatusUsecase {
  final RecoverBullRepository _repository;

  const FetchRecoverBullStatusUsecase(this._repository);

  Future<RecoverBullStatus> execute() => _repository.fetchBackupStatus();
}

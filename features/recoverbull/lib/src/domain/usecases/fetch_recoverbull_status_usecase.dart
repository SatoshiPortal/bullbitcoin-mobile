import '../entities/recoverbull_network.dart';
import '../entities/recoverbull_status.dart';
import '../repositories/recoverbull_repository.dart';

final class FetchRecoverBullStatusUsecase {
  final RecoverBullRepository _repository;

  const FetchRecoverBullStatusUsecase(this._repository);

  Future<RecoverBullStatus> execute(RecoverBullNetwork network) =>
      _repository.fetchBackupStatus(network);
}

import '../entities/recoverbull_network.dart';
import '../repositories/recoverbull_repository.dart';

final class MarkRecoverBullBackupVerifiedUsecase {
  final RecoverBullRepository _repository;

  const MarkRecoverBullBackupVerifiedUsecase(this._repository);

  Future<void> execute(RecoverBullNetwork network) =>
      _repository.markBackupVerified(network);
}

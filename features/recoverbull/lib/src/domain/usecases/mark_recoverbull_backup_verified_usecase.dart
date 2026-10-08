import '../repositories/recoverbull_repository.dart';

final class MarkRecoverBullBackupVerifiedUsecase {
  final RecoverBullRepository _repository;

  const MarkRecoverBullBackupVerifiedUsecase(this._repository);

  Future<void> execute() => _repository.markBackupVerified();
}

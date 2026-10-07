import '../repositories/recoverbull_repository.dart';

final class MarkRecoverBullBackupStoredUsecase {
  final RecoverBullRepository _repository;

  const MarkRecoverBullBackupStoredUsecase(this._repository);

  Future<void> execute() => _repository.markBackupStored();
}

import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';

class TrashBackupKeyFromServerUsecase {
  final RecoverBullRepository _recoverBullRepository;

  TrashBackupKeyFromServerUsecase({
    required RecoverBullRepository recoverBullRepository,
  }) : _recoverBullRepository = recoverBullRepository;

  Future<void> execute({
    required String identifier,
    required String password,
    required String salt,
    required String backupKey,
  }) async {
    // TODO: implem
    return _recoverBullRepository.trashBackupKey(identifier, password, salt);
  }
}

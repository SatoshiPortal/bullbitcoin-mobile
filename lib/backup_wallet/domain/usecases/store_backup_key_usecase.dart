import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';

class StoreBackupKeyUsecase {
  final RecoverBullRepository _recoverBullRepository;

  StoreBackupKeyUsecase({
    required RecoverBullRepository recoverBullRepository,
  }) : _recoverBullRepository = recoverBullRepository;

  Future<void> execute({
    required String identifier,
    required String password,
    required String salt,
    required String backupKey,
  }) async {
    return _recoverBullRepository.storeBackupKey(
      identifier,
      password,
      salt,
      backupKey,
    );
  }
}

import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';

class StoreBackupKeyIntoServerUsecase {
  final RecoverBullRepository _recoverBullRepository;

  StoreBackupKeyIntoServerUsecase({
    required RecoverBullRepository recoverBullRepository,
  }) : _recoverBullRepository = recoverBullRepository;

  Future<void> execute({
    required String password,
    required String backupFile,
  }) async {
    // TODO: implem
    // TODO: ensure that the backup key can decipher the backup

    // return _recoverBullRepository.storeBackupKey(
    //   identifier,
    //   password,
    //   salt,
    //   backupKey,
    // );
  }
}

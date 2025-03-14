import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';

class CreateEncryptedBackupUsecase {
  final RecoverBullRepository _recoverBullRepository;

  CreateEncryptedBackupUsecase({
    required RecoverBullRepository recoverBullRepository,
  }) : _recoverBullRepository = recoverBullRepository;

  Future<String> execute({required String defaultWalletFingerPrint}) async {
    return _recoverBullRepository.createBackupFile(defaultWalletFingerPrint);
  }
}

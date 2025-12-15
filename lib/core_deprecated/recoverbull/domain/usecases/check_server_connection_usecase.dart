import 'package:bb_mobile/core_deprecated/recoverbull/data/repository/recoverbull_repository.dart';

class CheckServerConnectionUsecase {
  final RecoverBullRepository _recoverBullRepository;

  CheckServerConnectionUsecase({
    required RecoverBullRepository recoverBullRepository,
  }) : _recoverBullRepository = recoverBullRepository;

  Future<bool> execute() async {
    try {
      await _recoverBullRepository.checkConnection();
      return true;
    } catch (e) {
      return false;
    }
  }
}

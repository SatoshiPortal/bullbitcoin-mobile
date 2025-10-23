import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';

class CheckKeyServerConnectionUsecase {
  final RecoverBullRepository _recoverBullRepository;

  CheckKeyServerConnectionUsecase({
    required RecoverBullRepository recoverBullRepository,
  }) : _recoverBullRepository = recoverBullRepository;

  Future<bool> execute() async {
    try {
      await _recoverBullRepository.checkKeyServerConnectionWithTor();
      return true;
    } catch (e) {
      return false;
    }
  }
}

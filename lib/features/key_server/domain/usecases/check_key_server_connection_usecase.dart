import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';

class CheckKeyServerConnectionUsecase {
  final RecoverBullRepository _recoverBullRepository;

  Future<void> execute() async {
    try {
      return await _recoverBullRepository.checkKeyServerConnectionWithTor();
    } catch (e) {
      rethrow;
    }
  }

  CheckKeyServerConnectionUsecase({
    required RecoverBullRepository recoverBullRepository,
  }) : _recoverBullRepository = recoverBullRepository;
}

import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';

class CheckServerConnectionUsecase {
  final RecoverBullRepository _recoverBullRepository;

  CheckServerConnectionUsecase({
    required this._recoverBullRepository,
  });

  Future<bool> execute() async {
    try {
      await _recoverBullRepository.checkConnection();
      return true;
    } catch (e) {
      return false;
    }
  }
}

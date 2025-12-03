import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';

class FetchPermissionUsecase {
  final RecoverBullRepository _recoverBullRepository;

  FetchPermissionUsecase({required RecoverBullRepository recoverBullRepository})
    : _recoverBullRepository = recoverBullRepository;

  Future<bool> execute() async {
    return await _recoverBullRepository.fetchPermission();
  }
}

import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';

class AllowPermissionUsecase {
  final RecoverBullRepository _recoverBullRepository;

  AllowPermissionUsecase({required RecoverBullRepository recoverBullRepository})
    : _recoverBullRepository = recoverBullRepository;

  Future<void> execute(bool isGranted) async {
    await _recoverBullRepository.allowPermission(isGranted);
  }
}

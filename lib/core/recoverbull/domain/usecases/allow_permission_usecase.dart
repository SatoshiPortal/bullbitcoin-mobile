import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';

class AllowPermissionUsecase {
  final RecoverBullRepository _recoverBullRepository;

  AllowPermissionUsecase({required this._recoverBullRepository});

  Future<void> execute(bool isGranted) async {
    await _recoverBullRepository.allowPermission(isGranted);
  }
}

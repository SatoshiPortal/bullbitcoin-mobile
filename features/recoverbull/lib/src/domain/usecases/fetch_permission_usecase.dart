import '../repositories/recoverbull_repository.dart';

class FetchPermissionUsecase {
  final RecoverBullRepository _recoverBullRepository;

  FetchPermissionUsecase({required this._recoverBullRepository});

  Future<bool> execute() async {
    return await _recoverBullRepository.fetchPermission();
  }
}

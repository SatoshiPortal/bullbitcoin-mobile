import 'package:primitives/primitives.dart';
import '../recoverbull_failure.dart';
import '../repositories/recoverbull_repository.dart';

class AllowPermissionUsecase {
  final RecoverBullRepository _recoverBullRepository;

  AllowPermissionUsecase({required this._recoverBullRepository});

  Future<Result<Null, RecoverBullFailure>> execute(bool isGranted) =>
      _recoverBullRepository.allowPermission(isGranted);
}

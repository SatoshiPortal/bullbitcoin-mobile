import 'package:primitives/primitives.dart';
import '../recoverbull_failure.dart';
import '../repositories/recoverbull_repository.dart';

class FetchPermissionUsecase {
  final RecoverBullRepository _recoverBullRepository;

  FetchPermissionUsecase({required this._recoverBullRepository});

  Future<Result<bool, RecoverBullFailure>> execute() =>
      _recoverBullRepository.fetchPermission();
}

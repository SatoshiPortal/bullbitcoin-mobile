import 'package:primitives/primitives.dart';
import '../recoverbull_failure.dart';
import '../entities/recoverbull_network.dart';
import '../repositories/recoverbull_repository.dart';

final class MarkRecoverBullBackupStoredUsecase {
  final RecoverBullRepository _repository;

  const MarkRecoverBullBackupStoredUsecase(this._repository);

  Future<Result<Null, RecoverBullFailure>> execute(
    RecoverBullNetwork network,
  ) => _repository.markBackupStored(network);
}

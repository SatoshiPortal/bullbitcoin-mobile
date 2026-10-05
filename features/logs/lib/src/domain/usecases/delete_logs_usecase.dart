import 'package:primitives/primitives.dart';
import 'package:bull_logs/src/domain/repositories/logs_repository.dart';
import 'package:bull_logs/src/domain/logs_failure.dart';
import 'package:meta/meta.dart';

class DeleteLogsUsecase {
  final LogsRepository _repository;

  const DeleteLogsUsecase(this._repository);

  @useResult
  Future<Result<void, LogsFailure>> execute() => _repository.delete();
}

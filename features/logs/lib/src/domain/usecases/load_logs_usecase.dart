import 'package:primitives/primitives.dart';
import 'package:bull_logs/src/domain/log_entry.dart';
import 'package:bull_logs/src/domain/repositories/logs_repository.dart';
import 'package:bull_logs/src/domain/logs_failure.dart';
import 'package:meta/meta.dart';

class LoadLogsUsecase {
  final LogsRepository _repository;

  const LoadLogsUsecase(this._repository);

  @useResult
  Future<Result<List<LogEntry>, LogsFailure>> execute() => _repository.read();
}

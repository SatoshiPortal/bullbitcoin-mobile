import 'package:primitives/primitives.dart';
import 'package:bull_logs/src/domain/log_entry.dart';
import 'package:bull_logs/src/domain/repositories/logs_repository.dart';
import 'package:bull_logs/src/domain/logs_failure.dart';
import 'package:meta/meta.dart';

class ExportLogsUsecase {
  final LogsRepository _repository;

  const ExportLogsUsecase(this._repository);

  @useResult
  Future<Result<bool, LogsFailure>> execute(List<LogEntry> entries) =>
      _repository.export(entries);
}

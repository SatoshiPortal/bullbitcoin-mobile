import 'package:primitives/primitives.dart';
import 'package:bull_logs/src/domain/log_entry.dart';
import 'package:bull_logs/src/domain/logs_failure.dart';
import 'package:meta/meta.dart';

abstract interface class LogsRepository {
  @useResult
  Future<Result<List<LogEntry>, LogsFailure>> read();

  @useResult
  Future<Result<void, LogsFailure>> delete();

  @useResult
  Future<Result<void, LogsFailure>> share(List<LogEntry> entries);

  @useResult
  Future<Result<bool, LogsFailure>> export(List<LogEntry> entries);
}

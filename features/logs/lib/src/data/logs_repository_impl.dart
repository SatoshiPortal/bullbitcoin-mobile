import 'package:primitives/primitives.dart';
import 'package:bull_logs/src/data/datasources/export_logs_datasource.dart';
import 'package:bull_logs/src/data/datasources/logger_logs_datasource.dart';
import 'package:bull_logs/src/data/datasources/share_logs_datasource.dart';
import 'package:bull_logs/src/data/log_entry_mapper.dart';
import 'package:bull_logs/src/data/log_entry_model.dart';
import 'package:bull_logs/src/domain/log_entry.dart';
import 'package:bull_logs/src/domain/repositories/logs_repository.dart';
import 'package:bull_logs/src/domain/logs_failure.dart';

class LogsRepositoryImpl implements LogsRepository {
  final LoggerLogsDatasource _loggerDatasource;
  final ShareLogsDatasource _shareDatasource;
  final ExportLogsDatasource _exportDatasource;

  LogsRepositoryImpl(
    this._loggerDatasource,
    this._shareDatasource,
    this._exportDatasource,
  );

  @override
  Future<Result<List<LogEntry>, LogsFailure>> read() async {
    try {
      final entries =
          (await _loggerDatasource.read())
              .map(LogEntryModel.fromRawLine)
              .map((model) => model.toDomain())
              .toList()
            ..sort(_newestFirst);
      return Ok(entries);
    } catch (error) {
      return Err(LogsStorageFailure(error.toString()));
    }
  }

  @override
  Future<Result<void, LogsFailure>> delete() async {
    try {
      await _loggerDatasource.delete();
      return const Ok(null);
    } catch (error) {
      return Err(LogsStorageFailure(error.toString()));
    }
  }

  @override
  Future<Result<void, LogsFailure>> share(List<LogEntry> entries) async {
    try {
      final lines = entries.map((entry) => entry.rawLine).toList();
      await _shareDatasource.share(
        await _loggerDatasource.createLogBundleLines(lines),
      );
      return const Ok(null);
    } catch (error) {
      return Err(LogsStorageFailure(error.toString()));
    }
  }

  @override
  Future<Result<bool, LogsFailure>> export(List<LogEntry> entries) async {
    try {
      final lines = entries.map((entry) => entry.rawLine).toList();
      return Ok(
        await _exportDatasource.export(
          await _loggerDatasource.createLogBundleLines(lines),
        ),
      );
    } catch (error) {
      return Err(LogsStorageFailure(error.toString()));
    }
  }

  static int _newestFirst(LogEntry a, LogEntry b) {
    if (a.timestamp == null || b.timestamp == null) {
      return a.timestamp == b.timestamp ? 0 : (a.timestamp == null ? 1 : -1);
    }
    return b.timestamp!.compareTo(a.timestamp!);
  }
}

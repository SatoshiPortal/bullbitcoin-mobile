import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/data/datasources/export_logs_datasource.dart';
import 'package:bb_mobile/features/settings/data/datasources/logger_logs_datasource.dart';
import 'package:bb_mobile/features/settings/data/datasources/share_logs_datasource.dart';
import 'package:bb_mobile/features/settings/data/log_entry_mapper.dart';
import 'package:bb_mobile/features/settings/data/models/log_entry_model.dart';
import 'package:bb_mobile/features/settings/domain/log_entry.dart';
import 'package:bb_mobile/features/settings/domain/repositories/logs_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';

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
  Future<Result<List<LogEntry>, SettingsFailure>> read() async {
    try {
      final entries =
          (await _loggerDatasource.read())
              .map(LogEntryModel.fromRawLine)
              .map((model) => model.toDomain())
              .toList()
            ..sort(_newestFirst);
      return Ok(entries);
    } catch (error) {
      return Err(SettingsLogsFailure(error.toString()));
    }
  }

  @override
  Future<Result<void, SettingsFailure>> delete() async {
    try {
      await _loggerDatasource.delete();
      return const Ok(null);
    } catch (error) {
      return Err(SettingsLogsFailure(error.toString()));
    }
  }

  @override
  Future<Result<void, SettingsFailure>> share(List<LogEntry> entries) async {
    try {
      await _shareDatasource.share(
        entries.map((entry) => entry.rawLine).toList(),
      );
      return const Ok(null);
    } catch (error) {
      return Err(SettingsLogsFailure(error.toString()));
    }
  }

  @override
  Future<Result<bool, SettingsFailure>> export(List<LogEntry> entries) async {
    try {
      return Ok(
        await _exportDatasource.export(
          entries.map((entry) => entry.rawLine).toList(),
        ),
      );
    } catch (error) {
      return Err(SettingsLogsFailure(error.toString()));
    }
  }

  static int _newestFirst(LogEntry a, LogEntry b) {
    if (a.timestamp == null || b.timestamp == null) {
      return a.timestamp == b.timestamp ? 0 : (a.timestamp == null ? 1 : -1);
    }
    return b.timestamp!.compareTo(a.timestamp!);
  }
}

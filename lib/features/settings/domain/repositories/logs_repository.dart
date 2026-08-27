import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/log_entry.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';

abstract interface class LogsRepository {
  @useResult
  Future<Result<List<LogEntry>, SettingsFailure>> read();

  @useResult
  Future<Result<void, SettingsFailure>> delete();

  @useResult
  Future<Result<void, SettingsFailure>> share(List<LogEntry> entries);

  @useResult
  Future<Result<bool, SettingsFailure>> export(List<LogEntry> entries);
}

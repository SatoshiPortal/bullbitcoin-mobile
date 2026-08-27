import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/log_entry.dart';
import 'package:bb_mobile/features/settings/domain/repositories/logs_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class ExportLogsUsecase {
  final LogsRepository _repository;

  const ExportLogsUsecase(this._repository);

  @useResult
  Future<Result<bool, SettingsFailure>> execute(List<LogEntry> entries) =>
      _repository.export(entries);
}

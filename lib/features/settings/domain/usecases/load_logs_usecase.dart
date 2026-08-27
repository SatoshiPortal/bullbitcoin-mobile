import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/log_entry.dart';
import 'package:bb_mobile/features/settings/domain/repositories/logs_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class LoadLogsUsecase {
  final LogsRepository _repository;

  const LoadLogsUsecase(this._repository);

  @useResult
  Future<Result<List<LogEntry>, SettingsFailure>> execute() =>
      _repository.read();
}

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/log_entry.dart';
import 'package:bb_mobile/features/settings/domain/repositories/logs_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class ShareLogsUsecase {
  final LogsRepository _repository;

  const ShareLogsUsecase(this._repository);

  @useResult
  Future<Result<void, SettingsFailure>> execute(List<LogEntry> entries) =>
      _repository.share(entries);
}

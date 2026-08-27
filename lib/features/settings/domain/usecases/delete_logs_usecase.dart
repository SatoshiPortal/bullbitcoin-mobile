import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/repositories/logs_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class DeleteLogsUsecase {
  final LogsRepository _repository;

  const DeleteLogsUsecase(this._repository);

  @useResult
  Future<Result<void, SettingsFailure>> execute() => _repository.delete();
}

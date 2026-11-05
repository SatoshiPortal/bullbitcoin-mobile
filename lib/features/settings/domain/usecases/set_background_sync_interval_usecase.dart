import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/repositories/background_sync_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class SetBackgroundSyncIntervalUsecase {
  final BackgroundSyncRepository _repository;

  const SetBackgroundSyncIntervalUsecase({required this._repository});

  @useResult
  Future<Result<void, SettingsFailure>> execute(
    BackgroundSyncInterval interval,
  ) => _repository.setInterval(interval);
}

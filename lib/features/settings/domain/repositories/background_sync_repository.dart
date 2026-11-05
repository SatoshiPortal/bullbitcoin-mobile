import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';

/// How often the system is asked to check for payments in the background.
abstract interface class BackgroundSyncRepository {
  @useResult
  Future<Result<BackgroundSyncInterval, SettingsFailure>> interval();

  /// Saves [interval] and reschedules the background checks with it.
  @useResult
  Future<Result<void, SettingsFailure>> setInterval(
    BackgroundSyncInterval interval,
  );
}

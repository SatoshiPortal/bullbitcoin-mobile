import 'package:primitives/primitives.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/background_sync_interval.dart';
import '../domain/background_tasks_failure.dart';
import '../domain/repositories/background_sync_interval_repository.dart';

/// Shared preferences, readable before the app database is opened and from
/// the background engine.
final class SharedPreferencesBackgroundSyncIntervalRepository
    implements BackgroundSyncIntervalRepository {
  static const _key = 'background_sync_interval';

  const SharedPreferencesBackgroundSyncIntervalRepository();

  @override
  Future<BackgroundSyncInterval> read() async {
    final preferences = await SharedPreferences.getInstance();
    // Another Flutter engine may have persisted an opt-out since our last read.
    await preferences.reload();
    final name = preferences.getString(_key);
    return BackgroundSyncInterval.values.firstWhere(
      (interval) => interval.name == name,
      orElse: () => BackgroundSyncInterval.fallback,
    );
  }

  @override
  Future<Result<void, BackgroundTasksFailure>> write(
    BackgroundSyncInterval interval,
  ) async {
    try {
      final saved = await (await SharedPreferences.getInstance()).setString(
        _key,
        interval.name,
      );
      return saved
          ? const Ok(null)
          : const Err(BackgroundSyncIntervalFailure());
    } on Exception {
      return const Err(BackgroundSyncIntervalFailure());
    }
  }
}

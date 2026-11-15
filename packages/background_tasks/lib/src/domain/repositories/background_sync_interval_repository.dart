import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../background_sync_interval.dart';
import '../background_tasks_failure.dart';

/// The interval the user chose. Each read sees a choice another Flutter
/// engine persisted since, so an opt-out stops a run already started.
abstract interface class BackgroundSyncIntervalRepository {
  Future<BackgroundSyncInterval> read();

  @useResult
  Future<Result<void, BackgroundTasksFailure>> write(
    BackgroundSyncInterval interval,
  );
}

import 'package:primitives/primitives.dart';

sealed class BackgroundTasksFailure extends Failure {
  const BackgroundTasksFailure();
}

final class BackgroundTasksStorageFailure extends BackgroundTasksFailure {
  const BackgroundTasksStorageFailure();
}

/// The lease expired and another run took the job over.
final class BackgroundTasksClaimLostFailure extends BackgroundTasksFailure {
  const BackgroundTasksClaimLostFailure();
}

/// The store does not exist, or cannot be opened.
final class BackgroundTasksStoreUnavailableFailure
    extends BackgroundTasksFailure {
  const BackgroundTasksStoreUnavailableFailure();
}

/// The store has another schema version; nothing migrates it.
final class BackgroundTasksStoreVersionFailure extends BackgroundTasksFailure {
  final int version;
  const BackgroundTasksStoreVersionFailure(this.version);
}

/// The platform could not save the chosen interval.
final class BackgroundSyncIntervalFailure extends BackgroundTasksFailure {
  const BackgroundSyncIntervalFailure();
}

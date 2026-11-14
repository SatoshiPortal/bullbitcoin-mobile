import 'package:bb_mobile/background_entrypoint.dart' as current;

/// Retains the callback symbol persisted by older WorkManager registrations.
/// Remove only once supported upgrades can no longer retain those registrations.
@pragma('vm:entry-point')
void backgroundTasksHandler() => current.backgroundTasksHandler();

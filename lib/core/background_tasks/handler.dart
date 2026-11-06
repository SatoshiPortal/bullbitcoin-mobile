import 'package:bb_mobile/background_entrypoint.dart' as current;

/// Retains the callback symbol persisted by older WorkManager registrations.
@pragma('vm:entry-point')
void backgroundTasksHandler() => current.backgroundTasksHandler();

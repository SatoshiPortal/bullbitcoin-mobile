/// Why a sync was requested.
///
/// Determines the [SyncCoordinator] throttle policy: [user] gestures
/// (pull-to-refresh and other explicit actions) bypass the per-kind throttle;
/// [automatic] triggers (startup, navigation, lifecycle resume) respect it.
/// [scheduled] is the desktop interval timer: throttled like [automatic], but
/// not held back while the window is hidden, since the app is still running.
enum SyncTrigger { user, automatic, scheduled }

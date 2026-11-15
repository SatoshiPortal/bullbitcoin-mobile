/// Why a sync was requested.
///
/// Determines the [SyncCoordinator] throttle policy: [user] gestures
/// (pull-to-refresh and other explicit actions) bypass the per-kind throttle;
/// [automatic] triggers (startup, navigation, lifecycle resume) respect it.
enum SyncTrigger { user, automatic }

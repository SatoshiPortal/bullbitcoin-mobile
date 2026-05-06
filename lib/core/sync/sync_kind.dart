/// The kinds of sync the [SyncCoordinator] can schedule.
///
/// Extend by adding a new value here and a matching `case` branch in
/// `SyncCoordinator._runTask`.
enum SyncKind { bitcoin, liquid, swaps }

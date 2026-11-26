import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

/// The system's notification permission: read, requested or handed to the
/// system settings. The answer always comes from the system.
class NotificationPermissionUsecase {
  NotificationPermissionUsecase({required this._permissions});

  final NotificationPermissionsFacade _permissions;

  /// `refused` is true when notifications are still not shown after a
  /// request: the system may not ask again, or the payment channel alone is
  /// blocked, and only its settings can change it.
  Future<({bool allowed, bool refused})> execute({
    bool request = false,
    bool openSettings = false,
  }) async {
    if (request) await _permissions.request();
    if (openSettings) await _permissions.openSystemSettings();
    final allowed = switch (await _permissions.isEnabled()) {
      Ok(:final value) => value,
      Err() => false,
    };
    return (allowed: allowed, refused: request && !allowed);
  }
}

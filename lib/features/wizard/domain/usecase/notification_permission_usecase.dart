import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

/// The system's notification permission: read, requested or handed to the
/// system settings. The answer always comes from the system.
class NotificationPermissionUsecase {
  NotificationPermissionUsecase({required this._permissions});

  final NotificationPermissionsFacade _permissions;

  /// `refused` is true when a request just made was turned down: the system
  /// may not ask again, only its settings can grant it.
  Future<({bool allowed, bool refused})> execute({
    bool request = false,
    bool openSettings = false,
  }) async {
    var refused = false;
    if (request) {
      refused = switch (await _permissions.request()) {
        Ok(:final value) => !value,
        Err() => true,
      };
    }
    if (openSettings) await _permissions.openSystemSettings();
    final allowed = switch (await _permissions.isEnabled()) {
      Ok(:final value) => value,
      Err() => false,
    };
    return (allowed: allowed, refused: refused && !allowed);
  }
}

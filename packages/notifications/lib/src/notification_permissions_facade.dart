import 'package:primitives/primitives.dart';

import 'domain/ports/notification_permission_port.dart';
import 'domain/notifications_failure.dart';

/// Notification permission only: needs no outbox, so it also serves the
/// startup wizard before the app is initialized.
final class NotificationPermissionsFacade {
  final NotificationPermissionPort gateway;

  const NotificationPermissionsFacade({required this.gateway});

  Future<Result<bool, NotificationsFailure>> isEnabled() => gateway.isEnabled();

  Future<Result<bool, NotificationsFailure>> request() =>
      gateway.requestPermission();

  Future<Result<void, NotificationsFailure>> openSystemSettings() =>
      gateway.openSystemSettings();
}

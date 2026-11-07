import 'package:primitives/primitives.dart';

import 'domain/notification_permission_gateway.dart';
import 'domain/notifications_failure.dart';

/// Notification permission only: needs no outbox, so it also serves the
/// startup wizard before the app is initialized.
final class NotificationPermissionsFacade {
  final NotificationPermissionGateway gateway;

  const NotificationPermissionsFacade({required this.gateway});

  Future<Result<bool, NotificationsFailure>> isEnabled() => gateway.isEnabled();

  Future<Result<bool, NotificationsFailure>> request() =>
      gateway.requestPermission();

  Future<Result<void, NotificationsFailure>> openSystemSettings() =>
      gateway.openSystemSettings();
}

import 'local_notification.dart';
import 'notification_permission_gateway.dart';
import 'notifications_failure.dart';
import 'package:primitives/primitives.dart';

typedef NotificationResponseCallback =
    Result<void, NotificationsFailure> Function(String payload);

abstract interface class LocalNotificationGateway
    implements NotificationPermissionGateway {
  Future<Result<void, NotificationsFailure>> initialize(
    NotificationResponseCallback onResponse,
  );

  Future<Result<void, NotificationsFailure>> show(
    LocalNotification notification, {
    required int platformId,
  });
}

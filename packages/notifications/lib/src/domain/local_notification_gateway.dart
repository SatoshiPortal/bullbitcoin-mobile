import 'package:meta/meta.dart';
import 'local_notification.dart';
import 'notification_permission_gateway.dart';
import 'notifications_failure.dart';
import 'package:primitives/primitives.dart';

abstract interface class LocalNotificationGateway
    implements NotificationPermissionGateway {
  /// Prepares the platform plugin. A tap on a notification opens the app.
  @useResult
  Future<Result<void, NotificationsFailure>> initialize();

  @useResult
  Future<Result<void, NotificationsFailure>> show(
    LocalNotification notification, {
    required int platformId,
  });
}

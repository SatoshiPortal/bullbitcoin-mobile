import 'package:meta/meta.dart';
import '../local_notification.dart';
import 'notification_permission_port.dart';
import '../notifications_failure.dart';
import 'package:primitives/primitives.dart';

abstract interface class LocalNotificationPort
    implements NotificationPermissionPort {
  /// Prepares the platform plugin. A tap on a notification opens the app.
  @useResult
  Future<Result<void, NotificationsFailure>> initialize();

  @useResult
  Future<Result<void, NotificationsFailure>> show(
    LocalNotification notification, {
    required int platformId,
  });
}

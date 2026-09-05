import 'local_notification.dart';
import 'notifications_failure.dart';
import 'package:primitives/primitives.dart';

typedef NotificationResponseCallback =
    Result<void, NotificationsFailure> Function(String payload);

abstract interface class LocalNotificationGateway {
  Future<Result<bool, NotificationsFailure>> requestPermission();

  Future<Result<void, NotificationsFailure>> initialize(
    NotificationResponseCallback onResponse,
  );

  Future<Result<void, NotificationsFailure>> show(
    LocalNotification notification, {
    required int platformId,
  });
}

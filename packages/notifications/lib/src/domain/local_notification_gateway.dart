import 'local_notification.dart';
import 'notifications_failure.dart';
import 'package:primitives/primitives.dart';

typedef NotificationResponseCallback =
    Result<void, NotificationsFailure> Function(String payload);

abstract interface class LocalNotificationGateway {
  Future<Result<bool, NotificationsFailure>> requestPermission();

  /// Whether the OS currently shows the app's notifications.
  Future<Result<bool, NotificationsFailure>> isEnabled();

  Future<Result<void, NotificationsFailure>> initialize(
    NotificationResponseCallback onResponse,
  );

  Future<Result<void, NotificationsFailure>> show(
    LocalNotification notification, {
    required int platformId,
  });
}

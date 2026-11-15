import 'package:primitives/primitives.dart';

import 'data/flutter_local_notification_gateway.dart';
import 'data/flutter_notification_permission_gateway.dart';
import 'data/sqlite_notification_store_repository.dart';
import 'domain/notifications_failure.dart';
import 'domain/ports/local_notification_port.dart';
import 'domain/ports/notification_permission_port.dart';
import 'domain/repositories/notification_store_repository.dart';

/// Opens the notification store at [path], creating it on first use. Only
/// the foreground calls it; [NotificationStoreRepository.close] releases it.
Result<NotificationStoreRepository, NotificationsFailure>
openForegroundNotificationStore(String path) =>
    SqliteNotificationStoreRepository.openForeground(path);

/// Opens a store the foreground created, never creating nor migrating it:
/// a missing, older or newer store is refused.
Result<NotificationStoreRepository, NotificationsFailure>
openExistingNotificationStore(String path) =>
    SqliteNotificationStoreRepository.openExisting(path);

/// The platform notifications, shown on the Android channel [channelId].
LocalNotificationPort localNotifications({
  required String channelId,
  required String channelName,
  required String androidIconResource,
  String? channelDescription,
}) => FlutterLocalNotificationGateway(
  channelId: channelId,
  channelName: channelName,
  androidIconResource: androidIconResource,
  channelDescription: channelDescription,
);

/// The OS permission alone: needs no store, so it also serves the startup
/// wizard before the app is initialized.
NotificationPermissionPort notificationPermissions({
  required String channelId,
}) => FlutterNotificationPermissionGateway(channelId: channelId);

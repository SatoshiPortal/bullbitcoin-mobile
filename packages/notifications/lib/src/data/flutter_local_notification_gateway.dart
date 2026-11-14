import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:primitives/primitives.dart';

import '../domain/local_notification.dart';
import '../domain/ports/local_notification_port.dart';
import '../domain/notifications_failure.dart';
import 'flutter_notification_permission_gateway.dart';

final class FlutterLocalNotificationGateway implements LocalNotificationPort {
  final FlutterLocalNotificationsPlugin _plugin;
  final FlutterNotificationPermissionGateway _permissions;

  final String channelId;
  final String channelName;
  final String? channelDescription;
  final String androidIconResource;

  /// A tap opens the app: no notification carries a destination payload.
  FlutterLocalNotificationGateway({
    required this.channelId,
    required this.channelName,
    required this.androidIconResource,
    this.channelDescription,
    // Phase A only: lib/features/wallet still passes false; removed with it.
    bool emitDestinations = false,
  }) : assert(!emitDestinations, 'Notifications carry no destination'),
       _plugin = FlutterLocalNotificationsPlugin(),
       _permissions = FlutterNotificationPermissionGateway(
         channelId: channelId,
       );

  @override
  Future<Result<bool, NotificationsFailure>> requestPermission() =>
      _permissions.requestPermission();

  @override
  Future<Result<bool, NotificationsFailure>> isEnabled() =>
      _permissions.isEnabled();

  @override
  Future<Result<void, NotificationsFailure>> openSystemSettings() =>
      _permissions.openSystemSettings();

  @override
  Future<Result<void, NotificationsFailure>> initialize() async {
    try {
      final initialized = await _plugin.initialize(
        settings: InitializationSettings(
          android: AndroidInitializationSettings(androidIconResource),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      return initialized == true
          ? const Ok(null)
          : const Err(NotificationsGatewayFailure());
    } on Exception catch (_) {
      return const Err(NotificationsGatewayFailure());
    }
  }

  @override
  Future<Result<void, NotificationsFailure>> show(
    LocalNotification notification, {
    required int platformId,
  }) async {
    try {
      await _plugin.show(
        id: platformId,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      return const Ok(null);
    } on Exception catch (_) {
      return const Err(NotificationsGatewayFailure());
    }
  }
}

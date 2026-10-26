import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:primitives/primitives.dart';

import '../domain/local_notification.dart';
import '../domain/local_notification_gateway.dart';
import '../domain/notifications_failure.dart';
import '../domain/notification_payload_codec.dart';

final class FlutterLocalNotificationGateway
    implements LocalNotificationGateway {
  final FlutterLocalNotificationsPlugin _plugin;

  final String channelId;
  final String channelName;
  final String? channelDescription;
  final String androidIconResource;
  final NotificationPayloadCodec _codec;

  FlutterLocalNotificationGateway({
    required this.channelId,
    required this.channelName,
    required this.androidIconResource,
    this.channelDescription,
    this._codec = const NotificationPayloadCodec(),
  }) : _plugin = FlutterLocalNotificationsPlugin();

  @override
  Future<Result<bool, NotificationsFailure>> requestPermission() async {
    try {
      final bool? granted;
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          granted = await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission();
        case TargetPlatform.iOS:
          granted = await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true);
        case TargetPlatform.macOS:
          granted = await _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true);
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          granted = true;
      }
      return Ok(granted ?? true);
    } catch (_) {
      return const Err(NotificationsGatewayFailure());
    }
  }

  @override
  Future<Result<void, NotificationsFailure>> initialize(
    NotificationResponseCallback onResponse,
  ) async {
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
        onDidReceiveNotificationResponse: (response) =>
            onResponse(response.payload ?? ''),
      );
      if (initialized != true) return const Err(NotificationsGatewayFailure());
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if (launch?.didNotificationLaunchApp == true && payload != null) {
        final persisted = onResponse(payload);
        if (persisted case Err(:final failure)) return Err(failure);
      }
      return const Ok(null);
    } catch (_) {
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
        payload: _codec.encode(notification.destination),
      );
      return const Ok(null);
    } catch (_) {
      return const Err(NotificationsGatewayFailure());
    }
  }
}

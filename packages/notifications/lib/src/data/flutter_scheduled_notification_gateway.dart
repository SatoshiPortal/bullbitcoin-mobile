import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/local_notification.dart';
import '../domain/notifications_failure.dart';
import '../domain/ports/scheduled_notification_port.dart';
import 'flutter_notification_permission_gateway.dart';

/// Scheduled safety reminders use a dedicated high-importance channel.
/// Inexact idle alarms need no exact-alarm permission. The OS may delay them;
/// a reminder never substitutes for observing and renewing the wallet.
final class FlutterScheduledNotificationGateway
    implements ScheduledNotificationPort {
  final FlutterLocalNotificationsPlugin _plugin;
  final FlutterNotificationPermissionGateway _permissions;
  final String channelId;
  final String channelName;
  final String? channelDescription;

  FlutterScheduledNotificationGateway({
    required this.channelId,
    required this.channelName,
    this.channelDescription,
  }) : _plugin = FlutterLocalNotificationsPlugin(),
       _permissions = FlutterNotificationPermissionGateway(
         channelId: channelId,
       );

  @override
  Future<Result<void, NotificationsFailure>> schedule(
    LocalNotification notification, {
    required int platformId,
    required DateTime at,
  }) async {
    switch (await _permissions.isEnabled()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: false):
        return const Err(NotificationsPermissionDeniedFailure());
      case Ok():
        break;
    }
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        onlyAlertOnce: true,
      ),
      iOS: const DarwinNotificationDetails(
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
    try {
      if (at.isAfter(DateTime.now())) {
        await _plugin.zonedSchedule(
          id: platformId,
          title: notification.title,
          body: notification.body,
          scheduledDate: tz.TZDateTime.from(at, tz.UTC),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } else {
        // show does not remove an existing pending alarm for this identifier.
        // Cancel first so an older future alarm cannot reappear after urgency.
        await _plugin.cancel(id: platformId);
        await _plugin.show(
          id: platformId,
          title: notification.title,
          body: notification.body,
          notificationDetails: details,
        );
      }
      return const Ok(null);
    } on Exception catch (_) {
      return const Err(NotificationsGatewayFailure());
    }
  }

  @override
  Future<Result<void, NotificationsFailure>> cancelScheduled(
    int platformId,
  ) async {
    try {
      await _plugin.cancel(id: platformId);
      return const Ok(null);
    } on Exception catch (_) {
      return const Err(NotificationsGatewayFailure());
    }
  }
}

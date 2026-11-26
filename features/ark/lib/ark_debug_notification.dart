/// A synthetic notification for verifying the production Ark channel.
library;

import 'dart:ui';

import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

import 'ark_notification_setup.dart';

/// Ark reminders allocate negative IDs and ordinary notifications positive IDs.
/// Zero is reserved for this synthetic notification.
const arkDebugNotificationId = 0;

Future<Result<void, NotificationsFailure>> scheduleArkDebugNotification({
  required ScheduledNotificationPort gateway,
  required Locale locale,
  required DateTime now,
}) {
  final copy = arkExpiryCopy(locale);
  return gateway.schedule(
    LocalNotification(
      eventId: 'ark-debug-expiry',
      title: copy.title,
      body: copy.body,
      createdAt: now,
    ),
    platformId: arkDebugNotificationId,
    at: now.add(const Duration(seconds: 60)),
  );
}

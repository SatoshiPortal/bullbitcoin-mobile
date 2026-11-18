import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../local_notification.dart';
import '../notifications_failure.dart';

/// Separate capability: existing payment delivery does not require a scheduler.
/// The host assigns a stable, unique ID per reminder; scheduling replaces that
/// ID atomically at the platform boundary, without cancelling first.
abstract interface class ScheduledNotificationPort {
  @useResult
  Future<Result<void, NotificationsFailure>> schedule(
    LocalNotification notification, {
    required int platformId,
    required DateTime at,
  });

  @useResult
  Future<Result<void, NotificationsFailure>> cancelScheduled(int platformId);
}

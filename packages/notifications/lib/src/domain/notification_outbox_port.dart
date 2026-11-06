import 'package:meta/meta.dart';
import 'local_notification.dart';
import 'notifications_failure.dart';
import 'package:primitives/primitives.dart';
import 'notification_reconcile_result.dart';

final class NotificationTopicObservation {
  final String topicId;
  final List<LocalNotification> observedEvents;

  NotificationTopicObservation(
    this.topicId,
    List<LocalNotification> observedEvents,
  ) : observedEvents = List.unmodifiable(observedEvents);
}

final class ClaimedNotification {
  final LocalNotification notification;
  final String claimToken;
  final int platformId;

  const ClaimedNotification({
    required this.notification,
    required this.claimToken,
    required this.platformId,
  });
}

abstract interface class NotificationOutboxPort {
  /// Atomically initializes a missing topic from baselineEvents without seen
  /// marks, then marks observedEvents (foreground sync discoveries) seen.
  /// Existing topics never absorb baselineEvents. Drops fully seen aggregates.
  @useResult
  Future<Result<void, NotificationsFailure>> recordObserved(
    String topicId,
    List<LocalNotification> observedEvents, {
    List<LocalNotification> baselineEvents = const [],
  });

  @useResult
  Future<Result<NotificationReconcileResult, NotificationsFailure>>
  reconcileTopicsAndEnqueue(
    List<NotificationTopicObservation> observations,
    LocalNotification Function(List<LocalNotification> newEvents)
    aggregateEvent,
  );

  /// Whether every payment this aggregate announces was seen in the app.
  @useResult
  Future<Result<bool, NotificationsFailure>> isSeen(String eventId);

  @useResult
  Future<Result<List<ClaimedNotification>, NotificationsFailure>> claimPending({
    DateTime? now,
  });

  @useResult
  Future<Result<void, NotificationsFailure>> markDelivered(
    String eventId,
    String claimToken,
  );

  @useResult
  Future<Result<void, NotificationsFailure>> release(
    String eventId,
    String claimToken,
  );

  @useResult
  Result<void, NotificationsFailure> persistResponse(String payload);

  @useResult
  Future<Result<String?, NotificationsFailure>> consumeResponse();
}

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
  Future<Result<void, NotificationsFailure>> enqueue(LocalNotification event);

  Future<Result<NotificationReconcileResult, NotificationsFailure>>
  reconcileTopic(String topicId, List<LocalNotification> observedEvents);

  Future<Result<NotificationReconcileResult, NotificationsFailure>>
  reconcileTopicsAndEnqueue(
    List<NotificationTopicObservation> observations,
    LocalNotification Function(List<LocalNotification> newEvents)
    aggregateEvent,
  );

  Future<Result<List<ClaimedNotification>, NotificationsFailure>> claimPending({
    DateTime? now,
  });

  Future<Result<void, NotificationsFailure>> markDelivered(
    String eventId,
    String claimToken,
  );

  Future<Result<void, NotificationsFailure>> release(
    String eventId,
    String claimToken,
  );

  Result<void, NotificationsFailure> persistResponse(String payload);

  Future<Result<String?, NotificationsFailure>> consumeResponse();
}

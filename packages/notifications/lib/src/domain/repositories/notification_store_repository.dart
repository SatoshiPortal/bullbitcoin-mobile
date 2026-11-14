import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../local_notification.dart';
import '../notifications_failure.dart';
import '../observation.dart';

/// What a background observation did with its topic.
enum BackgroundObservation {
  /// The foreground never observed the topic: nothing is recorded.
  topicNotInitialized,

  /// Every event was already stored.
  nothingNew,

  /// The new events became one pending aggregate.
  enqueued,
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

/// Observed events per topic and the aggregates waiting to be shown.
abstract interface class NotificationStoreRepository {
  /// Records the complete history a foreground sync saw. The first one
  /// initializes the topic silently, even when the history is empty.
  @useResult
  Future<Result<void, NotificationsFailure>> recordForeground(
    Observation observation,
  );

  /// Records the complete history a background sync saw. An uninitialized
  /// topic is ignored. Events stored for the first time become one pending
  /// aggregate, built by [aggregate], in the same transaction.
  @useResult
  Future<Result<BackgroundObservation, NotificationsFailure>> recordBackground(
    Observation observation,
    LocalNotification Function(List<String> newEventIds) aggregate,
  );

  /// Claims the oldest pending aggregate, or one whose claim expired.
  @useResult
  Future<Result<ClaimedNotification?, NotificationsFailure>> claimNext({
    DateTime? now,
  });

  /// Deletes a claimed aggregate once shown, or deliberately not shown.
  @useResult
  Future<Result<void, NotificationsFailure>> settle(ClaimedNotification claim);

  /// Gives a claimed aggregate back for a later delivery.
  @useResult
  Future<Result<void, NotificationsFailure>> release(ClaimedNotification claim);

  Future<void> close();
}

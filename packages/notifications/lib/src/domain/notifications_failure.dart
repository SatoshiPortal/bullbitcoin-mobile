import 'package:primitives/primitives.dart';

sealed class NotificationsFailure extends Failure {
  const NotificationsFailure();
}

final class NotificationsStorageFailure extends NotificationsFailure {
  const NotificationsStorageFailure();
}

final class NotificationsGatewayFailure extends NotificationsFailure {
  const NotificationsGatewayFailure();
}

/// The OS will not show notifications for the app: pending ones are settled
/// without being shown, so granting the permission later replays nothing.
final class NotificationsPermissionDeniedFailure extends NotificationsFailure {
  const NotificationsPermissionDeniedFailure();
}

/// The OS did not say whether it shows the app's notifications: pending ones
/// stay pending for a later attempt.
final class NotificationsPermissionUndeterminedFailure
    extends NotificationsFailure {
  const NotificationsPermissionUndeterminedFailure();
}

final class NotificationsClaimLostFailure extends NotificationsFailure {
  const NotificationsClaimLostFailure();
}

/// The store does not exist, or cannot be opened.
final class NotificationsStoreUnavailableFailure extends NotificationsFailure {
  const NotificationsStoreUnavailableFailure();
}

/// The store has another schema version; nothing migrates it.
final class NotificationsStoreVersionFailure extends NotificationsFailure {
  final int version;
  const NotificationsStoreVersionFailure(this.version);
}

/// Every platform notification ID was allocated once already.
final class NotificationsPlatformIdsExhaustedFailure
    extends NotificationsFailure {
  const NotificationsPlatformIdsExhaustedFailure();
}

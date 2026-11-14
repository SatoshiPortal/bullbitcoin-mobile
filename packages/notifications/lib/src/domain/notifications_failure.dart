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

final class NotificationsClaimLostFailure extends NotificationsFailure {
  const NotificationsClaimLostFailure();
}

final class UnknownNotificationDestinationFailure extends NotificationsFailure {
  const UnknownNotificationDestinationFailure();
}

final class InvalidNotificationPayloadFailure extends NotificationsFailure {
  const InvalidNotificationPayloadFailure();
}

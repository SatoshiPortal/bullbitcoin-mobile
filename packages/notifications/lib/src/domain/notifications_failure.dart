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

/// The OS will not show notifications for the app, so pending ones are kept
/// for a later run instead of being marked delivered.
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

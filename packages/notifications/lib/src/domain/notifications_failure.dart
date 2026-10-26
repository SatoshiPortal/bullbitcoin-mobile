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

final class NotificationsClaimLostFailure extends NotificationsFailure {
  const NotificationsClaimLostFailure();
}

final class UnknownNotificationDestinationFailure extends NotificationsFailure {
  const UnknownNotificationDestinationFailure();
}

final class InvalidNotificationPayloadFailure extends NotificationsFailure {
  const InvalidNotificationPayloadFailure();
}

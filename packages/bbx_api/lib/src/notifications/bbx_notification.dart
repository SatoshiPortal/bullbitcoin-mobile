import 'package:meta/meta.dart';

/// Severity of a notification socket diagnostic.
enum BbxNotificationLogLevel { fine, info, warning }

/// Receives the socket's diagnostics. [message] is a fixed text and [error]
/// is at most the failure's runtime type; neither carries frames or keys.
typedef BbxNotificationLog = void Function(
  BbxNotificationLogLevel level,
  String message, {
  Type? error,
});

/// The kinds of exchange notification a consumer can react to.
enum BbxNotificationKind {
  balance,
  group,
  kyc,
  userPreferences,
  message,
  order,
  limitOrder,
  user,
  recipient,
  unknown,
}

/// An owned notification event decoded from the notification socket.
///
/// The wire object and its unrecognized fields stay inside the package. An
/// unknown `type` is preserved as [BbxNotificationKind.unknown].
@immutable
final class BbxNotification {
  final BbxNotificationKind kind;
  final String? orderId;
  final String? event;

  const BbxNotification({required this.kind, this.orderId, this.event});
}

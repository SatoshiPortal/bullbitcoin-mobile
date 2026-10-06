/// The kinds of exchange notification the app reacts to. The wire strings are
/// parsed in the data layer so presentation never matches on them.
enum NotificationMessageKind {
  balance,
  group,
  kyc,
  userPreferences,
  message,
  order,
  limitOrder,
  user,
  unknown,
}

class NotificationMessage {
  final NotificationMessageKind kind;
  final String? orderId;
  final Map<String, dynamic> rawData;

  const NotificationMessage({
    required this.kind,
    this.orderId,
    required this.rawData,
  });
}

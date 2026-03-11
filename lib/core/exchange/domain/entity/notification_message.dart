class NotificationMessage {
  final String type; // 'user', 'message', 'order'
  final String? orderId; // For order-specific messages
  final Map<String, dynamic> rawData;

  const NotificationMessage({
    required this.type,
    this.orderId,
    required this.rawData,
  });
}


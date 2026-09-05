import 'notification_destination.dart';

final class LocalNotification {
  final String eventId;
  final String title;
  final String body;
  final NotificationDestination destination;
  final DateTime createdAt;

  const LocalNotification({
    required this.eventId,
    required this.title,
    required this.body,
    required this.destination,
    required this.createdAt,
  });
}

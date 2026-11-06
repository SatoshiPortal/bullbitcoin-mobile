import 'dart:convert';

import 'notification_destination.dart';
import 'notifications_failure.dart';
import 'package:primitives/primitives.dart';

final class NotificationPayloadCodec {
  const NotificationPayloadCodec();

  String encode(NotificationDestination destination) =>
      jsonEncode({'destination': destination.wireValue});

  Result<NotificationDestination, NotificationsFailure> decode(String payload) {
    try {
      final value = jsonDecode(payload);
      final destination = value is Map<String, dynamic>
          ? NotificationDestination.fromWire(
              value['destination'] as String? ?? '',
            )
          : null;
      return destination == null
          ? const Err(UnknownNotificationDestinationFailure())
          : Ok(destination);
    } catch (_) {
      return const Err(InvalidNotificationPayloadFailure());
    }
  }
}

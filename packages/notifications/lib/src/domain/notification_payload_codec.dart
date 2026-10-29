import 'dart:convert';
import 'notification_destination.dart';
import 'notifications_failure.dart';
import 'package:primitives/primitives.dart';

final class NotificationPayloadCodec {
  const NotificationPayloadCodec();
  String encode(NotificationDestination destination) =>
      jsonEncode(switch (destination) {
        WalletHomeNotificationDestination() => {'destination': 'wallet_home'},
        WalletNotificationDestination(:final walletKey) => {
          'destination': 'wallet',
          'walletKey': walletKey,
        },
      });

  Result<NotificationDestination, NotificationsFailure> decode(String payload) {
    try {
      final value = jsonDecode(payload);
      if (value case {
        'destination': 'wallet',
        'walletKey': final String key,
      } when RegExp(r'^[0-9a-f]{64}$').hasMatch(key)) {
        return Ok(NotificationDestination.wallet(key));
      }
      final destination = switch (value) {
        {'destination': final String type} => NotificationDestination.fromWire(
          type,
        ),
        _ => null,
      };
      return destination == null
          ? const Err(UnknownNotificationDestinationFailure())
          : Ok(destination);
    } catch (_) {
      return const Err(InvalidNotificationPayloadFailure());
    }
  }
}

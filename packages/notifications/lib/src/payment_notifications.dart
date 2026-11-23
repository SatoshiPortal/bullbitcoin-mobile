import 'dart:ui' show Locale;

import '../generated/l10n/notifications_localizations.dart';
import 'domain/ports/local_notification_port.dart';
import 'notifications_facade.dart';
import 'notifications_factories.dart';
import 'payment_notification_store.dart';

/// Platform channel and localized announcements for incoming payments.
abstract final class PaymentNotifications {
  static const channelId = 'bull_wallet_payments';

  static NotificationsLocalizations _localization(Locale? locale) =>
      lookupNotificationsLocalizations(locale ?? const Locale('en'));

  static LocalNotificationPort gateway(Locale? locale) => localNotifications(
    channelId: channelId,
    channelName: _localization(locale).receivePaymentReceived,
    androidIconResource: 'ic_launcher_foreground',
  );

  /// The headless task owns the lifetime of the existing payment outbox.
  static Future<NotificationsFacade?> initializeBackground(
    String documents,
    Locale? locale,
    void Function(Future<void> Function()) onClose,
  ) => openBackgroundPaymentNotifications(
    documents,
    gateway: () => gateway(locale),
    onClose: onClose,
  );

  static ({String title, String body}) Function(int count) copy(
    Locale? locale,
  ) {
    final localized = _localization(locale);
    return (count) => (
      title: localized.receivePaymentReceived,
      body: localized.backgroundPaymentCount(count),
    );
  }
}

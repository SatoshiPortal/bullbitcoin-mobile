import 'package:settings/settings.dart' show LanguageExtension;

import 'dart:ui';

import 'package:background_tasks/background_tasks.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:notifications/notifications.dart';
import 'package:notifications/payment_store.dart';

/// Public notification constants and localized copy belong to the wallet owner.
final class PaymentNotifications {
  static const channelId = 'bull_wallet_payments';

  static AppLocalizations localization(Language? language) =>
      lookupAppLocalizations(language?.locale ?? const Locale('en'));

  /// The payment channel. A tap opens the app: no notification carries a
  /// destination.
  static LocalNotificationPort gateway(Language? language) =>
      localNotifications(
        channelId: channelId,
        channelName: localization(language).receivePaymentReceived,
        androidIconResource: 'ic_launcher_foreground',
      );

  /// Notification storage and the platform plugin are optional to native
  /// sync. The store is never created nor migrated here: a missing, older or
  /// newer store leaves this run without notifications.
  static Future<NotificationsFacade?> initializeBackground(
    String documents,
    Language? language,
    BackgroundTaskResources resources,
  ) async {
    return openBackgroundPaymentNotifications(
      documents,
      gateway: () => gateway(language),
      onClose: resources.onClose,
    );
  }

  /// The localized text of an announcement of [count] new payments.
  static ({String title, String body}) Function(int count) copy(
    Language? language,
  ) {
    final localized = localization(language);
    return (count) => (
      title: localized.receivePaymentReceived,
      body: localized.backgroundPaymentCount(count),
    );
  }
}

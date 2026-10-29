import 'dart:ui' show Locale, PlatformDispatcher;
import 'package:flutter/widgets.dart' show basicLocaleListResolution;
import 'package:bb_mobile/generated/l10n/localization.dart';

const androidNotificationIconResource = 'ic_launcher_foreground';
const paymentNotificationChannelId = 'bull_wallet_payments';
const notificationOutboxFilename = 'notification_outbox.sqlite';

Locale resolveNotificationLocale(
  Locale? appLocale, {
  List<Locale>? systemLocales,
}) => basicLocaleListResolution(
  appLocale == null
      ? systemLocales ?? PlatformDispatcher.instance.locales
      : [appLocale],
  AppLocalizations.supportedLocales,
);

({String title, String body}) paymentNotificationCopy(
  AppLocalizations localized,
  int count,
  String chain, {
  bool confirmedOnly = false,
}) => (
  title: confirmedOnly
      ? localized.notificationPaymentConfirmed(count)
      : localized.receivePaymentReceived,
  body: confirmedOnly
      ? localized.notificationPaymentsChannel
      : localized.notificationTransactionsReceived(chain, count),
);

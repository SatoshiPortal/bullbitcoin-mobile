/// Notification copy and platform channel for Ark safety reminders.
library;

import 'dart:io';
import 'dart:ui';

import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

import 'generated/l10n/ark_localizations.dart';

const arkExpiryChannelId = 'bull_ark_expiry';

/// Initialize the shared plugin before using the scheduled gateway.
Future<Result<ScheduledNotificationPort, NotificationsFailure>>
initializeArkNotifications(Locale locale) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return const Err(NotificationsGatewayFailure());
  }
  final copy = lookupArkLocalizations(_supportedLocale(locale));
  final gateway = localNotifications(
    channelId: arkExpiryChannelId,
    channelName: copy.expiryTitle,
    androidIconResource: 'ic_launcher_foreground',
  );
  switch (await gateway.initialize()) {
    case Err(:final failure):
      return Err(failure);
    case Ok():
      return Ok(
        scheduledNotifications(
          channelId: arkExpiryChannelId,
          channelName: copy.expiryTitle,
        ),
      );
  }
}

({String title, String body}) arkExpiryCopy(Locale locale) {
  final copy = lookupArkLocalizations(_supportedLocale(locale));
  return (title: copy.expiryTitle, body: copy.expiryBody);
}

({String title, String body}) arkExitClaimableCopy(Locale locale) {
  final copy = lookupArkLocalizations(_supportedLocale(locale));
  return (title: copy.exitClaimableTitle, body: copy.exitClaimableBody);
}

Locale _supportedLocale(Locale locale) =>
    locale.languageCode == 'fr' ? const Locale('fr') : const Locale('en');

/// Refuses platform effects when plugin initialization failed. Durable intent
/// remains in the reminder ledger and the caller can retry after recovery.
ScheduledNotificationPort unavailableArkNotifications() =>
    const _UnavailableArkNotifications();

final class _UnavailableArkNotifications implements ScheduledNotificationPort {
  const _UnavailableArkNotifications();

  @override
  Future<Result<void, NotificationsFailure>> schedule(
    LocalNotification notification, {
    required int platformId,
    required DateTime at,
    bool cancelExisting = true,
  }) async => const Err(NotificationsGatewayFailure());

  @override
  Future<Result<void, NotificationsFailure>> cancelScheduled(
    int platformId,
  ) async => const Err(NotificationsGatewayFailure());
}

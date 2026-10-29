import 'dart:ui' show Locale;
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'dart:io';

import 'package:bb_mobile/core/notification_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unset app language follows system locale resolution', () {
    expect(
      resolveNotificationLocale(
        null,
        systemLocales: const [Locale('fr', 'CA')],
      ),
      const Locale('fr'),
    );
    expect(
      resolveNotificationLocale(
        const Locale('en'),
        systemLocales: const [Locale('fr')],
      ),
      const Locale('en'),
    );
    expect(
      resolveNotificationLocale(null, systemLocales: const [Locale('xx')]),
      AppLocalizations.supportedLocales.first,
    );
  });
  for (final locale in ['en', 'fr']) {
    test('payment copy uses one ICU plural message in $locale', () async {
      final loc = await AppLocalizations.delegate.load(Locale(locale));
      expect(
        paymentNotificationCopy(loc, 1, 'bitcoin', confirmedOnly: true).title,
        locale == 'fr' ? 'Paiement confirmé' : 'Payment confirmed',
      );
      expect(
        paymentNotificationCopy(loc, 2, 'bitcoin', confirmedOnly: true).title,
        locale == 'fr' ? '2 paiements confirmés' : '2 payments confirmed',
      );
      expect(
        paymentNotificationCopy(loc, 2, 'bitcoin').body,
        locale == 'fr'
            ? '2 paiements Bitcoin reçus'
            : '2 Bitcoin payments received',
      );
      expect(
        loc.notificationPaymentsChannel,
        isNot(loc.receivePaymentReceived),
      );
      expect(loc.notificationPaymentsChannelDescription, isNotEmpty);
    });
  }
  test('Android notification icon is packaged as a drawable resource', () {
    final resourceRoot = Directory('android/app/src/main/res');
    final drawableResources = resourceRoot
        .listSync()
        .whereType<Directory>()
        .where(
          (directory) => directory.uri.pathSegments
              .where((segment) => segment.isNotEmpty)
              .last
              .startsWith('drawable'),
        )
        .expand((directory) => directory.listSync())
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last.split('.').first);

    expect(drawableResources, contains(androidNotificationIconResource));
  });
}

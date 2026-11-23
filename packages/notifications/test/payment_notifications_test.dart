import 'dart:ui' show Locale;

import 'package:notifications/payment_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

void main() {
  test(
    'formats the announcement for the configured locale and payment count',
    () {
      final english = PaymentNotifications.copy(null);
      final french = PaymentNotifications.copy(const Locale('fr'));
      final hindi = PaymentNotifications.copy(
        const Locale.fromSubtags(languageCode: 'hi', scriptCode: 'Latn'),
      );
      expect(english(1), (
        title: 'Payment received!',
        body: 'You received a payment',
      ));
      expect(french(2), (
        title: 'Paiement reçu !',
        body: 'Vous avez reçu 2 paiements',
      ));
      expect(hindi(2), (
        title: 'Payment aa gayi!',
        body: 'You received 2 payments',
      ));
    },
  );

  test(
    'payment notifications open the app without an unconsumed destination',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final android = _Android();
      FlutterLocalNotificationsPlatform.instance = android;
      final gateway = PaymentNotifications.gateway(null);
      final shown = await gateway.show(
        LocalNotification(
          eventId: 'payment',
          title: 'Payment received',
          body: 'One payment',
          createdAt: DateTime.utc(2026),
        ),
        platformId: 1,
      );
      expect(shown, isA<Ok>());
      expect(android.channelId, 'bull_wallet_payments');
      expect(android.payload, isNull);
      expect(await gateway.initialize(), isA<Ok>());
      expect(android.response, isNull);
      expect(android.launchReads, 0);
    },
  );
}

class _Android extends AndroidFlutterLocalNotificationsPlugin {
  String? payload;
  String? channelId;
  DidReceiveNotificationResponseCallback? response;
  int launchReads = 0;
  @override
  Future<bool> initialize({
    required AndroidInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    response = onDidReceiveNotificationResponse;
    return true;
  }

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async {
    launchReads++;
    return const NotificationAppLaunchDetails(false);
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    AndroidNotificationDetails? notificationDetails,
    String? payload,
  }) async {
    this.payload = payload;
    channelId = notificationDetails?.channelId;
  }
}

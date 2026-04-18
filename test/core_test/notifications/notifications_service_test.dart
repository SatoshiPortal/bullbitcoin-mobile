import 'dart:convert';

import 'package:bb_mobile/core/notifications/notifications_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _FakeDetails extends Fake implements NotificationDetails {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_FakeDetails());
  });

  group('NotificationsService', () {
    late _MockPlugin plugin;
    late NotificationsService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      plugin = _MockPlugin();
      when(
        () => plugin.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});

      service = NotificationsService(plugin: plugin);
    });

    test('fires a notification on first call', () async {
      await service.showSwapNeedsAttention(
        swapId: 'swap1',
        walletId: 'wallet1',
        title: 'Title',
        body: 'Body',
      );
      verify(
        () => plugin.show(
          id: any(named: 'id'),
          title: 'Title',
          body: 'Body',
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        ),
      ).called(1);
    });

    test('dedups repeated notifications for the same swap within 1h', () async {
      await service.showSwapNeedsAttention(
        swapId: 'swap1',
        walletId: 'wallet1',
        title: 'Title',
        body: 'Body',
      );
      await service.showSwapNeedsAttention(
        swapId: 'swap1',
        walletId: 'wallet1',
        title: 'Title',
        body: 'Body',
      );
      verify(
        () => plugin.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        ),
      ).called(1);
    });

    test('does not dedup different swap ids', () async {
      await service.showSwapNeedsAttention(
        swapId: 'swap1',
        walletId: 'wallet1',
        title: 'Title',
        body: 'Body',
      );
      await service.showSwapNeedsAttention(
        swapId: 'swap2',
        walletId: 'wallet1',
        title: 'Title',
        body: 'Body',
      );
      verify(
        () => plugin.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        ),
      ).called(2);
    });

    test('payload encodes swapId and walletId as JSON', () async {
      await service.showSwapNeedsAttention(
        swapId: 'abc',
        walletId: 'xyz',
        title: 'T',
        body: 'B',
      );
      final captured =
          verify(
                () => plugin.show(
                  id: any(named: 'id'),
                  title: any(named: 'title'),
                  body: any(named: 'body'),
                  notificationDetails: any(named: 'notificationDetails'),
                  payload: captureAny(named: 'payload'),
                ),
              ).captured.single
              as String;
      final decoded = jsonDecode(captured) as Map<String, dynamic>;
      expect(decoded['swapId'], 'abc');
      expect(decoded['walletId'], 'xyz');
    });

    test('dedup window expires after 1h', () async {
      // Seed shared prefs with a timestamp just over 1h ago.
      final twoHoursAgo = DateTime.now()
          .subtract(const Duration(hours: 2))
          .millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'notif_swap_last_fired_swap1': twoHoursAgo,
      });
      // Re-create to pick up the seed (the existing instance still fine —
      // each call re-fetches SharedPreferences.getInstance).
      await service.showSwapNeedsAttention(
        swapId: 'swap1',
        walletId: 'wallet1',
        title: 'T',
        body: 'B',
      );
      verify(
        () => plugin.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        ),
      ).called(1);
    });
  });
}

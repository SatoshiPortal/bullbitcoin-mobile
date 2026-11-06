import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

class _Android extends AndroidFlutterLocalNotificationsPlugin {
  bool appEnabled = true;
  List<AndroidNotificationChannel>? channels = const [];

  @override
  Future<bool?> areNotificationsEnabled() async => appEnabled;

  @override
  Future<List<AndroidNotificationChannel>?> getNotificationChannels() async =>
      channels;
}

Matcher _ok(bool value) => isA<Ok<bool, NotificationsFailure>>().having(
  (r) => r.value,
  'value',
  value,
);

void main() {
  late _Android android;
  final gateway = FlutterLocalNotificationGateway(
    channelId: 'payments',
    channelName: 'Payments',
    androidIconResource: 'ic_notification',
  );

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    android = _Android();
    FlutterLocalNotificationsPlatform.instance = android;
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('a blocked payment channel reports notifications as hidden', () async {
    android.channels = const [
      AndroidNotificationChannel(
        'payments',
        'Payments',
        importance: Importance.none,
      ),
    ];

    expect(await gateway.isEnabled(), _ok(false));
  });

  test(
    'an allowed app with no channel yet reports notifications shown',
    () async {
      expect(await gateway.isEnabled(), _ok(true));
    },
  );

  test('another blocked channel does not hide payments', () async {
    android.channels = const [
      AndroidNotificationChannel('other', 'Other', importance: Importance.none),
      AndroidNotificationChannel('payments', 'Payments'),
    ];

    expect(await gateway.isEnabled(), _ok(true));
  });

  test('a disabled app reports notifications as hidden', () async {
    android.appEnabled = false;

    expect(await gateway.isEnabled(), _ok(false));
  });
}

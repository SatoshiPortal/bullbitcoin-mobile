import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

class _Android extends AndroidFlutterLocalNotificationsPlugin {
  bool? appEnabled = true;
  bool? granted = true;
  Object? failure;
  List<AndroidNotificationChannel>? channels = const [];

  @override
  Future<bool?> areNotificationsEnabled() async {
    final error = failure;
    if (error != null) throw error;
    return appEnabled;
  }

  @override
  Future<List<AndroidNotificationChannel>?> getNotificationChannels() async =>
      channels;

  @override
  Future<bool?> requestNotificationsPermission() async => granted;
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

  test(
    'plugin exceptions become failures but programming errors propagate',
    () async {
      android.failure = Exception('private platform detail');
      expect(await gateway.isEnabled(), isA<Err>());
      android.failure = StateError('programming error');
      await expectLater(gateway.isEnabled(), throwsStateError);
    },
  );

  test('a disabled app reports notifications as hidden', () async {
    android.appEnabled = false;

    expect(await gateway.isEnabled(), _ok(false));
  });

  test('an undetermined status is a failure, never a permission', () async {
    android.appEnabled = null;
    android.granted = null;

    final undetermined = isA<Err<bool, NotificationsFailure>>().having(
      (r) => r.failure,
      'failure',
      isA<NotificationsPermissionUndeterminedFailure>(),
    );
    expect(await gateway.isEnabled(), undetermined);
    expect(await gateway.requestPermission(), undetermined);
  });
}

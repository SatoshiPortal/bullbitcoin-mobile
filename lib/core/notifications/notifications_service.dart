import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsService {
  static const String _swapChannelId = 'swap_alerts';
  static const String _swapChannelName = 'Swap Alerts';
  static const String _swapChannelDescription =
      'Notifies when a Boltz swap needs your attention';
  static const String _dedupPrefsPrefix = 'notif_swap_last_fired_';
  static const Duration _dedupWindow = Duration(hours: 1);

  final FlutterLocalNotificationsPlugin _plugin;
  final Future<SharedPreferences> Function() _prefsFactory;

  bool _initialized = false;
  void Function(SwapNotificationTap tap)? _onTap;

  NotificationsService({
    FlutterLocalNotificationsPlugin? plugin,
    Future<SharedPreferences> Function()? prefsFactory,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _prefsFactory = prefsFactory ?? SharedPreferences.getInstance;

  /// Register the callback invoked when the user taps a swap notification.
  /// Call this from the foreground isolate once the router is available.
  /// Background isolates should not call this — they never handle taps.
  void setOnSwapNotificationTap(void Function(SwapNotificationTap tap) onTap) {
    _onTap = onTap;
  }

  /// Returns tap details for a notification that launched the app from
  /// a killed state (so the foreground can navigate on startup).
  Future<SwapNotificationTap?> getLaunchTap() async {
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails == null ||
        !launchDetails.didNotificationLaunchApp ||
        launchDetails.notificationResponse?.payload == null) {
      return null;
    }
    return _parsePayload(launchDetails.notificationResponse!.payload!);
  }

  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _handleTap,
    );

    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _swapChannelId,
          _swapChannelName,
          description: _swapChannelDescription,
          importance: Importance.high,
        ),
      );
      await androidPlugin?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Shows (at most once per [_dedupWindow] per swapId) a notification prompting
  /// the user to open the app to complete a Boltz swap action.
  Future<void> showSwapNeedsAttention({
    required String swapId,
    required String walletId,
    required String title,
    required String body,
  }) async {
    if (!await _shouldFire(swapId)) return;

    final payload = jsonEncode({'swapId': swapId, 'walletId': walletId});
    final notificationId = swapId.hashCode & 0x7fffffff;

    await _plugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _swapChannelId,
          _swapChannelName,
          channelDescription: _swapChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      payload: payload,
    );
    await _recordFired(swapId);
  }

  Future<bool> _shouldFire(String swapId) async {
    try {
      final prefs = await _prefsFactory();
      final last = prefs.getInt('$_dedupPrefsPrefix$swapId');
      if (last == null) return true;
      final elapsed = DateTime.now().millisecondsSinceEpoch - last;
      return elapsed >= _dedupWindow.inMilliseconds;
    } catch (e) {
      log.warning('NotificationsService dedup check failed: $e');
      return true;
    }
  }

  Future<void> _recordFired(String swapId) async {
    try {
      final prefs = await _prefsFactory();
      await prefs.setInt(
        '$_dedupPrefsPrefix$swapId',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      log.warning('NotificationsService dedup write failed: $e');
    }
  }

  void _handleTap(NotificationResponse response) {
    final payload = response.payload;
    final onTap = _onTap;
    if (payload == null || onTap == null) return;
    final tap = _parsePayload(payload);
    if (tap == null) return;
    onTap(tap);
  }

  SwapNotificationTap? _parsePayload(String payload) {
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final swapId = map['swapId'] as String?;
      final walletId = map['walletId'] as String?;
      if (swapId == null || walletId == null) return null;
      return SwapNotificationTap(swapId: swapId, walletId: walletId);
    } catch (e) {
      log.warning('NotificationsService tap parse failed: $e');
      return null;
    }
  }
}

class SwapNotificationTap {
  final String swapId;
  final String walletId;

  const SwapNotificationTap({required this.swapId, required this.walletId});
}

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:primitives/primitives.dart';

import '../domain/notification_permission_gateway.dart';
import '../domain/notifications_failure.dart';

/// Requests and status go through flutter_local_notifications, which needs no
/// plugin initialization for them; permission_handler only opens the
/// settings page, the one call that needs no iOS permission flag.
final class FlutterNotificationPermissionGateway
    implements NotificationPermissionGateway {
  final FlutterLocalNotificationsPlugin _plugin;

  final String channelId;

  FlutterNotificationPermissionGateway({required this.channelId})
    : _plugin = FlutterLocalNotificationsPlugin();

  @override
  Future<Result<bool, NotificationsFailure>> requestPermission() async {
    try {
      final bool? granted;
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          granted = await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission();
        case TargetPlatform.iOS:
          granted = await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true);
        case TargetPlatform.macOS:
          granted = await _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true);
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          granted = true;
      }
      // The plugin may not answer; only the OS decides, never a default.
      return granted == null
          ? const Err(NotificationsPermissionUndeterminedFailure())
          : Ok(granted);
    } on Exception catch (_) {
      return const Err(NotificationsGatewayFailure());
    }
  }

  @override
  Future<Result<bool, NotificationsFailure>> isEnabled() async {
    try {
      final bool? enabled;
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final android = _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
          // The user can block the payment channel alone while the app
          // itself stays allowed; a show on it is then a silent no-op.
          final channels = await android?.getNotificationChannels() ?? [];
          final blocked = channels.any(
            (c) => c.id == channelId && c.importance == Importance.none,
          );
          enabled = blocked ? false : await android?.areNotificationsEnabled();
        case TargetPlatform.iOS:
          enabled =
              (await _plugin
                      .resolvePlatformSpecificImplementation<
                        IOSFlutterLocalNotificationsPlugin
                      >()
                      ?.checkPermissions())
                  ?.isEnabled;
        case TargetPlatform.macOS:
          enabled =
              (await _plugin
                      .resolvePlatformSpecificImplementation<
                        MacOSFlutterLocalNotificationsPlugin
                      >()
                      ?.checkPermissions())
                  ?.isEnabled;
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          enabled = true;
      }
      // The plugin may not answer; only the OS decides, never a default.
      return enabled == null
          ? const Err(NotificationsPermissionUndeterminedFailure())
          : Ok(enabled);
    } on Exception catch (_) {
      return const Err(NotificationsGatewayFailure());
    }
  }

  @override
  Future<Result<void, NotificationsFailure>> openSystemSettings() async {
    try {
      return await openAppSettings()
          ? const Ok(null)
          : const Err(NotificationsGatewayFailure());
    } on Exception catch (_) {
      return const Err(NotificationsGatewayFailure());
    }
  }
}

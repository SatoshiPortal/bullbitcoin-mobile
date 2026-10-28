import 'dart:io';

import 'package:background_tasks/background_tasks.dart';
import 'package:flutter/services.dart';

/// Reads PowerManager through the app's own channel (MainActivity), since
/// permission_handler reports the state as denied unless the app declares the
/// Play-restricted REQUEST_IGNORE_BATTERY_OPTIMIZATIONS permission.
final class ChannelBackgroundActivityGateway
    implements BackgroundActivityGateway {
  static const _channel = MethodChannel(
    'com.bullbitcoin.mobile/background_activity',
  );

  const ChannelBackgroundActivityGateway();

  @override
  Future<bool?> isUnrestricted() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> openSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

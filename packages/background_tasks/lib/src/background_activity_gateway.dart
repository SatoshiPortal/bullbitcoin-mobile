import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Whether Android lets the app run in the background. Battery optimization,
/// enforced hard by some vendors (Samsung), keeps periodic tasks from running
/// at all until the user allows unrestricted battery use.
abstract interface class BackgroundActivityGateway {
  /// Null where it does not apply (iOS, desktop) or cannot be read.
  Future<bool?> isUnrestricted();

  /// Opens the app's system settings, whose battery page holds the choice.
  Future<bool> openSettings();
}

final class PermissionHandlerBackgroundActivityGateway
    implements BackgroundActivityGateway {
  const PermissionHandlerBackgroundActivityGateway();

  @override
  Future<bool?> isUnrestricted() async {
    if (!Platform.isAndroid) return null;
    try {
      return await Permission.ignoreBatteryOptimizations.status.isGranted;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }
}

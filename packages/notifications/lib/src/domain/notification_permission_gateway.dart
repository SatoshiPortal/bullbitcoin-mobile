import 'package:meta/meta.dart';
import 'notifications_failure.dart';
import 'package:primitives/primitives.dart';

/// The OS permission to show the app's notifications.
abstract interface class NotificationPermissionGateway {
  /// Whether the OS currently shows the app's payment notifications.
  @useResult
  Future<Result<bool, NotificationsFailure>> isEnabled();

  /// Shows the OS prompt when the OS still allows it, and reports whether
  /// notifications are allowed afterwards.
  @useResult
  Future<Result<bool, NotificationsFailure>> requestPermission();

  /// Opens the app's page in the system settings, the only way back once
  /// the OS stops prompting.
  @useResult
  Future<Result<void, NotificationsFailure>> openSystemSettings();
}

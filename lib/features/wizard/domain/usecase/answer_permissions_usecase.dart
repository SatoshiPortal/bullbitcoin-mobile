import 'package:bull_logger/bull_logger.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

/// The user's answer on the Permissions page: allowing shows the OS prompt,
/// declining changes nothing. Works before the app is initialized.
class AnswerPermissionsUsecase {
  AnswerPermissionsUsecase({required this._permissions});

  final NotificationPermissionsFacade _permissions;

  Future<void> execute({required bool allowNotifications}) async {
    if (!allowNotifications) return;
    switch (await _permissions.request()) {
      case Ok(:final value):
        log.config('Notification permission requested allowed=$value');
      case Err(:final failure):
        log.warning(
          'Notification permission request failed: ${failure.runtimeType}',
        );
    }
  }
}

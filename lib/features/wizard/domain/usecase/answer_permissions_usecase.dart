import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

/// The user's answer on the Permissions page: allowing shows the OS prompt,
/// declining changes nothing; either way the page is not offered again.
/// Works before the app is initialized.
class AnswerPermissionsUsecase {
  AnswerPermissionsUsecase({
    required this._permissions,
    required this._repository,
  });

  final NotificationPermissionsFacade _permissions;
  final WizardRepository _repository;

  Future<void> execute({required bool allowNotifications}) async {
    await _repository.markPermissionsIntroduced();
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

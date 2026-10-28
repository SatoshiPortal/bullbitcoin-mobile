import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

/// Whether to offer the Permissions page after unlock: once, to users who
/// never saw it in the wizard and have not allowed notifications already.
/// Claiming it marks it offered, so a closed app never offers it twice.
class TakePermissionsIntroUsecase {
  TakePermissionsIntroUsecase({
    required this._repository,
    required this._permissions,
  });

  final WizardRepository _repository;
  final NotificationPermissionsFacade _permissions;

  Future<bool> execute() async {
    if (await _repository.arePermissionsIntroduced()) return false;
    // An unreadable state is skipped this time, not consumed: a passing
    // failure must not cancel the only offer.
    final enabled = await _permissions.isEnabled();
    if (enabled case Ok(:final value)) {
      await _repository.markPermissionsIntroduced();
      return !value;
    }
    return false;
  }
}

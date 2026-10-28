import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';
import 'package:notifications/notifications.dart';

class OpenNotificationSettingsUsecase {
  final NotificationPermissionsFacade _permissions;

  const OpenNotificationSettingsUsecase({required this._permissions});

  @useResult
  Future<Result<void, SettingsFailure>> execute() async =>
      (await _permissions.openSystemSettings()).mapErr(
        (failure) => SettingsUnexpectedFailure(failure.runtimeType.toString()),
      );
}

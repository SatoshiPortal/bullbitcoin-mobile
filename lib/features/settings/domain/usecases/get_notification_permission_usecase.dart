import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';
import 'package:notifications/notifications.dart';

class GetNotificationPermissionUsecase {
  final NotificationPermissionsFacade _permissions;

  const GetNotificationPermissionUsecase({required this._permissions});

  /// Whether the OS shows the app's payment notifications.
  @useResult
  Future<Result<bool, SettingsFailure>> execute() async =>
      (await _permissions.isEnabled()).mapErr(
        (failure) => SettingsUnexpectedFailure(failure.runtimeType.toString()),
      );
}

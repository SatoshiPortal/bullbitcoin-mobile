import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';
import 'package:notifications/notifications.dart';

class RequestNotificationPermissionUsecase {
  final NotificationPermissionsFacade _permissions;

  const RequestNotificationPermissionUsecase({required this._permissions});

  /// Shows the OS prompt if the OS still allows it; reports whether
  /// notifications are allowed afterwards.
  @useResult
  Future<Result<bool, SettingsFailure>> execute() async =>
      (await _permissions.request()).mapErr(
        (failure) => SettingsUnexpectedFailure(failure.runtimeType.toString()),
      );
}

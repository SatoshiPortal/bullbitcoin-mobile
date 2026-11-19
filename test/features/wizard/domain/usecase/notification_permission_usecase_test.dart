import 'package:bb_mobile/features/wizard/domain/usecase/notification_permission_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

/// Grants every request; [shown] is whether notifications actually show.
class _Permissions implements NotificationPermissionPort {
  _Permissions({required this.shown});

  final bool shown;

  @override
  Future<Result<bool, NotificationsFailure>> isEnabled() async => Ok(shown);

  @override
  Future<Result<bool, NotificationsFailure>> requestPermission() async =>
      const Ok(true);

  @override
  Future<Result<void, NotificationsFailure>> openSystemSettings() async =>
      const Ok(null);
}

NotificationPermissionUsecase _usecase({required bool shown}) =>
    NotificationPermissionUsecase(
      permissions: NotificationPermissionsFacade(
        gateway: _Permissions(shown: shown),
      ),
    );

void main() {
  test(
    'a granted request still not shown leads to the system settings',
    () async {
      // The app is allowed but its payment channel alone is blocked.
      final result = await _usecase(shown: false).execute(request: true);
      expect(result, (allowed: false, refused: true));
    },
  );

  test('a read alone never reports a refusal', () async {
    expect(await _usecase(shown: false).execute(), (
      allowed: false,
      refused: false,
    ));
    expect(await _usecase(shown: true).execute(request: true), (
      allowed: true,
      refused: false,
    ));
  });
}

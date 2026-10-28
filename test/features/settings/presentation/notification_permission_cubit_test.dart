import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_notification_permission_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/open_notification_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/request_notification_permission_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/notification_permission_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';

class _Gateway implements NotificationPermissionGateway {
  Result<bool, NotificationsFailure> enabled = const Ok(false);
  bool grantOnRequest = false;
  Completer<void>? pendingPrompt;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<Result<bool, NotificationsFailure>> isEnabled() async => enabled;

  @override
  Future<Result<bool, NotificationsFailure>> requestPermission() async {
    requests++;
    await pendingPrompt?.future;
    if (grantOnRequest) enabled = const Ok(true);
    return enabled;
  }

  @override
  Future<Result<void, NotificationsFailure>> openSystemSettings() async {
    settingsOpened++;
    return const Ok(null);
  }
}

NotificationPermissionCubit _cubit(_Gateway gateway) {
  final permissions = NotificationPermissionsFacade(gateway: gateway);
  return NotificationPermissionCubit(
    getNotificationPermissionUsecase: GetNotificationPermissionUsecase(
      permissions: permissions,
    ),
    requestNotificationPermissionUsecase: RequestNotificationPermissionUsecase(
      permissions: permissions,
    ),
    openNotificationSettingsUsecase: OpenNotificationSettingsUsecase(
      permissions: permissions,
    ),
  );
}

void main() {
  test('refresh reports the OS state', () async {
    final gateway = _Gateway();
    final cubit = _cubit(gateway);
    addTearDown(cubit.close);

    await cubit.refresh();
    expect(cubit.state.status, NotificationPermissionStatus.off);

    gateway.enabled = const Ok(true);
    await cubit.refresh();
    expect(cubit.state.status, NotificationPermissionStatus.allowed);

    gateway.enabled = const Err(NotificationsGatewayFailure());
    await cubit.refresh();
    expect(cubit.state.status, NotificationPermissionStatus.unavailable);
  });

  test('a declined prompt leads to the system settings', () async {
    final gateway = _Gateway();
    final cubit = _cubit(gateway);
    addTearDown(cubit.close);

    await cubit.request();

    expect(cubit.state.status, NotificationPermissionStatus.off);
    expect(cubit.state.promptDeclined, isTrue);
    await cubit.openSystemSettings();
    expect(gateway.settingsOpened, 1);
  });

  test('a granted prompt reports notifications allowed', () async {
    final gateway = _Gateway()..grantOnRequest = true;
    final cubit = _cubit(gateway);
    addTearDown(cubit.close);

    await cubit.request();

    expect(cubit.state.status, NotificationPermissionStatus.allowed);
    expect(cubit.state.promptDeclined, isFalse);
  });

  test('a second tap while the prompt is open asks once', () async {
    final gateway = _Gateway()..pendingPrompt = Completer<void>();
    final cubit = _cubit(gateway);
    addTearDown(cubit.close);

    final first = cubit.request();
    await cubit.request();
    gateway.pendingPrompt?.complete();
    await first;

    expect(gateway.requests, 1);
    expect(cubit.state.busy, isFalse);
  });
}

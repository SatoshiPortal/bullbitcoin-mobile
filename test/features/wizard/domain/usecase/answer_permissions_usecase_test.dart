import 'dart:async';

import 'package:bb_mobile/features/wizard/domain/usecase/answer_permissions_usecase.dart';
import 'package:bb_mobile/features/wizard/presentation/permissions_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

class _Gateway implements NotificationPermissionGateway {
  int requests = 0;
  Completer<void>? pendingPrompt;

  @override
  Future<Result<bool, NotificationsFailure>> isEnabled() async =>
      const Ok(false);

  @override
  Future<Result<bool, NotificationsFailure>> requestPermission() async {
    requests++;
    await pendingPrompt?.future;
    return const Ok(true);
  }

  @override
  Future<Result<void, NotificationsFailure>> openSystemSettings() async =>
      const Ok(null);
}

AnswerPermissionsUsecase _usecase(_Gateway gateway) => AnswerPermissionsUsecase(
  permissions: NotificationPermissionsFacade(gateway: gateway),
);

void main() {
  test('allowing shows the OS prompt', () async {
    final gateway = _Gateway();

    await _usecase(gateway).execute(allowNotifications: true);

    expect(gateway.requests, 1);
  });

  test('declining never shows the OS prompt', () async {
    final gateway = _Gateway();

    await _usecase(gateway).execute(allowNotifications: false);

    expect(gateway.requests, 0);
  });

  test('a second tap while the prompt is open is ignored', () async {
    final gateway = _Gateway()..pendingPrompt = Completer<void>();
    final cubit = PermissionsCubit(answer: _usecase(gateway));
    addTearDown(cubit.close);

    final first = cubit.answer(allowNotifications: true);
    expect(await cubit.answer(allowNotifications: true), isFalse);
    gateway.pendingPrompt?.complete();

    expect(await first, isTrue);
    expect(gateway.requests, 1);
    expect(cubit.state, isFalse);
  });
}

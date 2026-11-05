import 'dart:async';

import 'package:bb_mobile/features/wizard/data/datasource/wizard_local_datasource.dart';
import 'package:bb_mobile/features/wizard/data/repository/wizard_repository_impl.dart';
import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/answer_permissions_usecase.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/take_permissions_intro_usecase.dart';
import 'package:bb_mobile/features/wizard/presentation/permissions_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Gateway implements NotificationPermissionGateway {
  int requests = 0;
  Completer<void>? pendingPrompt;
  Result<bool, NotificationsFailure> enabled = const Ok(false);

  @override
  Future<Result<bool, NotificationsFailure>> isEnabled() async => enabled;

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

final _repository = WizardRepositoryImpl(WizardLocalDatasourceImpl());

AnswerPermissionsUsecase _usecase(_Gateway gateway) => AnswerPermissionsUsecase(
  permissions: NotificationPermissionsFacade(gateway: gateway),
  repository: _repository,
);

TakePermissionsIntroUsecase _intro(_Gateway gateway) =>
    TakePermissionsIntroUsecase(
      repository: _repository,
      permissions: NotificationPermissionsFacade(gateway: gateway),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  test('the intro is offered once to a user who never saw it', () async {
    final gateway = _Gateway();

    expect(await _intro(gateway).execute(), isTrue);
    expect(await _intro(gateway).execute(), isFalse);
  });

  test('answering in the wizard means no intro after unlock', () async {
    final gateway = _Gateway();

    await _usecase(gateway).execute(allowNotifications: false);

    expect(await _intro(gateway).execute(), isFalse);
  });

  test('no intro when notifications are already allowed', () async {
    final gateway = _Gateway()..enabled = const Ok(true);

    expect(await _intro(gateway).execute(), isFalse);
  });

  test('an unreadable permission state skips the intro', () async {
    final gateway = _Gateway()
      ..enabled = const Err(NotificationsGatewayFailure());

    expect(await _intro(gateway).execute(), isFalse);
  });

  test('an unreadable permission state keeps the intro for later', () async {
    final gateway = _Gateway()
      ..enabled = const Err(NotificationsGatewayFailure());
    expect(await _intro(gateway).execute(), isFalse);

    gateway.enabled = const Ok(false);

    expect(await _intro(gateway).execute(), isTrue);
  });

  test('an answer that cannot be saved still frees the page', () async {
    final gateway = _Gateway();
    final cubit = PermissionsCubit(
      answer: AnswerPermissionsUsecase(
        permissions: NotificationPermissionsFacade(gateway: gateway),
        repository: _UnwritableRepository(),
      ),
    );
    addTearDown(cubit.close);

    expect(await cubit.answer(allowNotifications: true), isTrue);
    expect(cubit.state, isFalse);
    expect(gateway.requests, 1);
  });
}

final class _UnwritableRepository implements WizardRepository {
  @override
  Future<bool> arePermissionsIntroduced() async => false;

  @override
  Future<void> markPermissionsIntroduced() async =>
      throw StateError('preferences unavailable');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

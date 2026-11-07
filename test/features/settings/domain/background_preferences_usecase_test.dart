import 'dart:async';
import 'package:bb_mobile/features/settings/presentation/bloc/background_preferences_cubit.dart';
import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/repositories/background_preferences_repository.dart';
import 'package:bb_mobile/features/settings/domain/usecases/background_preferences_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

class Preferences implements BackgroundPreferencesRepository {
  int requests = 0;
  Completer<void>? pendingWrite;
  StateError? writeError;
  final started = Completer<void>();
  var selected = BackgroundSyncInterval.hour1;
  var failWrite = false;
  var failRead = false;
  @override
  Future<Result<BackgroundSyncInterval, SettingsFailure>> interval() async =>
      failRead ? const Err(SettingsStorageFailure()) : Ok(selected);
  @override
  Future<Result<bool, SettingsFailure>> notificationsAllowed() async =>
      const Ok(false);
  @override
  Future<Result<bool, SettingsFailure>> requestNotifications() async {
    requests++;
    return const Ok(false);
  }

  @override
  Future<Result<void, SettingsFailure>> openNotificationSettings() async =>
      const Ok(null);
  @override
  Future<Result<void, SettingsFailure>> setInterval(
    BackgroundSyncInterval value,
  ) async {
    if (!started.isCompleted) started.complete();
    await pendingWrite?.future;
    final error = writeError;
    writeError = null;
    if (error != null) throw error;
    if (failWrite) return const Err(SettingsStorageFailure());
    selected = value;
    return const Ok(null);
  }
}

void main() {
  test('Off waits for a pending interval change and wins', () async {
    final repository = Preferences()..pendingWrite = Completer<void>();
    final cubit = BackgroundPreferencesCubit(
      BackgroundPreferencesUsecase(repository),
    );
    addTearDown(cubit.close);
    final first = cubit.load(interval: BackgroundSyncInterval.minutes15);
    await repository.started.future;
    final off = cubit.load(interval: BackgroundSyncInterval.off);
    repository.pendingWrite?.complete();
    await Future.wait([first, off]);
    expect(repository.selected, BackgroundSyncInterval.off);
    expect(cubit.state.interval, BackgroundSyncInterval.off);
  });

  test(
    'Off still executes after a preceding programming error propagates',
    () async {
      final repository = Preferences()
        ..pendingWrite = Completer<void>()
        ..writeError = StateError('injected');
      final cubit = BackgroundPreferencesCubit(
        BackgroundPreferencesUsecase(repository),
      );
      addTearDown(cubit.close);
      final first = cubit.load(interval: BackgroundSyncInterval.minutes15);
      final errorReported = expectLater(first, throwsStateError);
      await repository.started.future;
      final offCompleted = expectLater(
        cubit.load(interval: BackgroundSyncInterval.off),
        completes,
      );
      repository.pendingWrite?.complete();
      await Future.wait([errorReported, offCompleted]);
      expect(repository.selected, BackgroundSyncInterval.off);
      expect(cubit.state.interval, BackgroundSyncInterval.off);
    },
  );

  test('read failures remain typed without requesting permission', () async {
    final repository = Preferences()..failRead = true;
    final state = await BackgroundPreferencesUsecase(repository).execute();
    expect(state.failure, isA<SettingsStorageFailure>());
    expect(repository.requests, 0);
  });

  test(
    'loading and interval changes never prompt; only explicit request does',
    () async {
      final repository = Preferences();
      final usecase = BackgroundPreferencesUsecase(repository);
      expect((await usecase.execute()).allowed, isFalse);
      await usecase.execute(interval: BackgroundSyncInterval.minutes30);
      expect(repository.requests, 0);
      expect(repository.selected, BackgroundSyncInterval.minutes30);
      expect((await usecase.execute(requestPermission: true)).allowed, isFalse);
      expect(repository.requests, 1);
    },
  );
  test(
    'failed preference write stays visible and preserves prior interval',
    () async {
      final repository = Preferences()..failWrite = true;
      final result = await BackgroundPreferencesUsecase(
        repository,
      ).execute(interval: BackgroundSyncInterval.off);
      expect(result.failure, isA<SettingsStorageFailure>());
      expect(repository.selected, BackgroundSyncInterval.hour1);
    },
  );
}

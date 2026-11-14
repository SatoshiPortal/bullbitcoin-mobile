import 'dart:io';

import 'package:bull_logger/bull_logger.dart';

import 'dart:async';

import 'package:bb_mobile/features/settings/data/background_preferences_repository_impl.dart';
import 'package:notifications/notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final latest in [
    BackgroundSyncInterval.off,
    BackgroundSyncInterval.minutes15,
  ]) {
    for (final action in ['request', 'settings', 'refresh']) {
      test('notification $action must not hide committed ${latest.name}', () async {
        final initial = latest == BackgroundSyncInterval.off
            ? BackgroundSyncInterval.hour1
            : BackgroundSyncInterval.off;
        SharedPreferences.setMockInitialValues({
          'background_sync_interval': initial.name,
        });
        final store = DelayedPersistentStore();
        final scheduler = Scheduler()
          ..registered = initial != BackgroundSyncInterval.off;
        final cubit = BackgroundPreferencesCubit(
          BackgroundPreferencesUsecase(
            BackgroundPreferencesRepositoryImpl(
              store,
              NotificationPermissionsFacade(gateway: Permissions()),
              () => applyBackgroundTaskSchedule(
                dispatcher: () {},
                scheduler: scheduler,
                desktopScheduler: scheduler,
                enabled: true,
              ),
            ),
          ),
        );
        addTearDown(cubit.close);
        await cubit.load();
        expect(cubit.state.interval, initial);
        final choice = cubit.load(interval: latest);
        await store.entered.future;
        final permission = cubit.load(
          requestPermission: action == 'request',
          openSettings: action == 'settings',
        );
        // Drain runnable reads/permission work while persistence is suspended.
        await Future<void>.delayed(Duration.zero);
        store.release.complete();
        await Future.wait([choice, permission]);
        expect(
          await const SharedPreferencesBackgroundSyncIntervalStore().read(),
          latest,
        );
        expect(scheduler.registered, latest != BackgroundSyncInterval.off);
        if (latest != BackgroundSyncInterval.off) {
          expect(scheduler.frequency, latest.frequency);
        }
        expect(
          cubit.state.interval,
          latest,
          reason:
              'After all actions finish, the UI must match the durable choice',
        );
      });
    }
  }

  test('closed settings cannot replay On after newer Off', () async {
    final permissions = DelayedPermissions();
    final scheduler = Scheduler();
    final repository = BackgroundPreferencesRepositoryImpl(
      const SharedPreferencesBackgroundSyncIntervalStore(),
      NotificationPermissionsFacade(gateway: permissions),
      () => applyBackgroundTaskSchedule(
        dispatcher: () {},
        scheduler: scheduler,
        desktopScheduler: scheduler,
        enabled: true,
      ),
    );
    final first = BackgroundPreferencesCubit(
      BackgroundPreferencesUsecase(repository),
    );
    final initial = first.load();
    await permissions.entered.future;
    final queued = first.load(interval: BackgroundSyncInterval.minutes15);
    await first.close();
    final reopened = BackgroundPreferencesCubit(
      BackgroundPreferencesUsecase(repository),
    );
    addTearDown(reopened.close);
    await reopened.load(interval: BackgroundSyncInterval.off);
    expect(reopened.state.interval, BackgroundSyncInterval.off);
    permissions.release.complete();
    await Future.wait([initial, queued]);
    expect(
      await const SharedPreferencesBackgroundSyncIntervalStore().read(),
      BackgroundSyncInterval.off,
    );
    expect(scheduler.registered, isFalse);
  });

  test('Off completes while an older schedule initializes', () async {
    final scheduler = Scheduler()..holdInitialization = true;
    final repository = BackgroundPreferencesRepositoryImpl(
      const SharedPreferencesBackgroundSyncIntervalStore(),
      NotificationPermissionsFacade(
        gateway: DelayedPermissions()..holdRead = false,
      ),
      () => applyBackgroundTaskSchedule(
        dispatcher: () {},
        scheduler: scheduler,
        desktopScheduler: scheduler,
        enabled: true,
      ),
    );
    final first = BackgroundPreferencesCubit(
      BackgroundPreferencesUsecase(repository),
    );
    final pending = first.load(interval: BackgroundSyncInterval.minutes15);
    await scheduler.entered.future;
    await first.close();
    final reopened = BackgroundPreferencesCubit(
      BackgroundPreferencesUsecase(repository),
    );
    addTearDown(reopened.close);
    await reopened.load(interval: BackgroundSyncInterval.off);
    expect(scheduler.registered, isFalse);
    scheduler.release.complete();
    await pending;
    expect(
      await const SharedPreferencesBackgroundSyncIntervalStore().read(),
      BackgroundSyncInterval.off,
    );
    expect(scheduler.registered, isFalse);
  });

  test(
    'Off cancels an already started registration before completing',
    () async {
      final scheduler = Scheduler()..holdRegistration = true;
      final repository = BackgroundPreferencesRepositoryImpl(
        const SharedPreferencesBackgroundSyncIntervalStore(),
        NotificationPermissionsFacade(gateway: Permissions()),
        () => applyBackgroundTaskSchedule(
          dispatcher: () {},
          scheduler: scheduler,
          desktopScheduler: scheduler,
          enabled: true,
        ),
      );
      final on = repository.setInterval(BackgroundSyncInterval.minutes15);
      await scheduler.entered.future;
      final off = repository.setInterval(BackgroundSyncInterval.off);
      // Let Off reach the scheduler while the old registration is suspended.
      await Future<void>.delayed(Duration.zero);
      scheduler.release.complete();
      expect(await on, isA<Ok>());
      expect(await off, isA<Ok>());
      expect(scheduler.registered, isFalse);
    },
  );

  test('cancellation failure retains persisted Off', () async {
    final directory = await Directory.systemTemp.createTemp('background-off-');
    log = Logger.replace(directory: directory);
    addTearDown(() async {
      await log.flush();
      await directory.delete(recursive: true);
    });
    final scheduler = Scheduler()..failCancellation = true;
    final repository = BackgroundPreferencesRepositoryImpl(
      const SharedPreferencesBackgroundSyncIntervalStore(),
      NotificationPermissionsFacade(gateway: Permissions()),
      () => applyBackgroundTaskSchedule(
        dispatcher: () {},
        scheduler: scheduler,
        desktopScheduler: scheduler,
        enabled: true,
      ),
    );
    expect(
      await repository.setInterval(BackgroundSyncInterval.off),
      isA<Err>(),
    );
    expect(
      await const SharedPreferencesBackgroundSyncIntervalStore().read(),
      BackgroundSyncInterval.off,
    );
    expect(scheduler.registered, isTrue);
    final messages = (await log.readLogs())
        .map((row) => row.split('\t')[2])
        .toList();
    expect(messages, contains('Background interval saved=off'));
    expect(
      messages.indexOf('Background interval saved=off'),
      lessThan(messages.indexOf('Background schedule update failed')),
    );
    expect(
      messages,
      isNot(contains('Background schedule applied interval=off')),
    );
  });

  test('shared repository skips obsolete queued writes and keeps closed-screen Off', () async {
    final store = DelayedStore();
    final repository = BackgroundPreferencesRepositoryImpl(
      store,
      NotificationPermissionsFacade(gateway: Permissions()),
      () async {},
    );
    final first = BackgroundPreferencesCubit(
      BackgroundPreferencesUsecase(repository),
    );
    final on = first.load(interval: BackgroundSyncInterval.minutes15);
    await store.entered.future;
    final obsolete = first.load(interval: BackgroundSyncInterval.minutes30);
    final second = BackgroundPreferencesCubit(
      BackgroundPreferencesUsecase(repository),
    );
    final off = second.load(interval: BackgroundSyncInterval.off);
    await first.close();
    await second.close();
    store.release.complete();
    await Future.wait([on, obsolete, off]);
    expect(store.writes, [
      BackgroundSyncInterval.minutes15,
      BackgroundSyncInterval.off,
    ]);
    expect(await store.read(), BackgroundSyncInterval.off);
  });

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
      final result = await BackgroundPreferencesUsecase(repository)
          .execute(interval: BackgroundSyncInterval.off);
      expect(result.failure, isA<SettingsStorageFailure>());
      expect(repository.selected, BackgroundSyncInterval.hour1);
    },
  );
}

class Scheduler implements BackgroundTaskScheduler {
  Duration? frequency;
  bool registered = true;
  bool failCancellation = false;
  bool holdInitialization = false;
  bool holdRegistration = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> initialize(BackgroundTaskDispatcher dispatcher) async {
    if (holdInitialization) {
      holdInitialization = false;
      entered.complete();
      await release.future;
    }
  }

  @override
  Future<void> cancelByUniqueName(String name) async {
    if (name == BackgroundTask.walletsSync.id) {
      if (failCancellation) throw Exception('injected cancellation failure');
      registered = false;
    }
  }

  @override
  Future<void> registerPeriodic({
    required String uniqueName,
    required String taskName,
    required Duration frequency,
    required bool requiresNetwork,
    Duration? initialDelay,
  }) async {
    if (uniqueName == BackgroundTask.walletsSync.id) {
      if (holdRegistration) {
        holdRegistration = false;
        entered.complete();
        await release.future;
      }
      registered = true;
      this.frequency = frequency;
    }
  }
}

class Permissions implements NotificationPermissionGateway {
  @override
  Future<Result<bool, NotificationsFailure>> isEnabled() async =>
      const Ok(false);
  @override
  Future<Result<bool, NotificationsFailure>> requestPermission() async =>
      const Ok(false);
  @override
  Future<Result<void, NotificationsFailure>> openSystemSettings() async =>
      const Ok(null);
}

class DelayedPermissions extends Permissions {
  final entered = Completer<void>();
  final release = Completer<void>();
  bool holdRead = true;
  @override
  Future<Result<bool, NotificationsFailure>> isEnabled() async {
    if (holdRead) {
      holdRead = false;
      entered.complete();
      await release.future;
    }
    return const Ok(false);
  }
}

class DelayedStore implements BackgroundSyncIntervalStore {
  final entered = Completer<void>();
  final release = Completer<void>();
  final writes = <BackgroundSyncInterval>[];
  BackgroundSyncInterval selected = BackgroundSyncInterval.hour1;
  @override
  Future<BackgroundSyncInterval> read() async => selected;
  @override
  Future<Result<void, BackgroundSyncIntervalFailure>> write(
    BackgroundSyncInterval value,
  ) async {
    writes.add(value);
    if (!entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    selected = value;
    return const Ok(null);
  }
}

class DelayedPersistentStore implements BackgroundSyncIntervalStore {
  final entered = Completer<void>();
  final release = Completer<void>();
  final _store = const SharedPreferencesBackgroundSyncIntervalStore();

  @override
  Future<BackgroundSyncInterval> read() => _store.read();

  @override
  Future<Result<void, BackgroundSyncIntervalFailure>> write(
    BackgroundSyncInterval value,
  ) async {
    if (!entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return _store.write(value);
  }
}

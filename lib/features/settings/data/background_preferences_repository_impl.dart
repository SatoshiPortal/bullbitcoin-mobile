import 'dart:async';
import 'package:bull_logger/bull_logger.dart';
import '../domain/settings_failure.dart';
import 'package:background_tasks/background_tasks.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import '../domain/repositories/background_preferences_repository.dart';

final class BackgroundPreferencesRepositoryImpl
    implements BackgroundPreferencesRepository {
  final BackgroundSyncIntervalStore _intervals;
  final NotificationPermissionsFacade _permissions;
  final Future<void> Function() _schedule;

  Future<void> _pendingWrite = Future.value();
  int _generation = 0;

  BackgroundPreferencesRepositoryImpl(
    this._intervals,
    this._permissions,
    this._schedule,
  );

  @override
  Future<Result<BackgroundSyncInterval, SettingsFailure>> interval() async {
    try {
      while (true) {
        final generation = _generation;
        // Wait for persistence only; scheduling must not block preference reads.
        await _pendingWrite;
        final interval = await _intervals.read();
        if (generation == _generation) return Ok(interval);
      }
    } on Exception {
      log.warning('Background interval read failed');
      return const Err(SettingsStorageFailure());
    }
  }

  @override
  Future<Result<bool, SettingsFailure>> notificationsAllowed() async =>
      (await _permissions.isEnabled()).mapErr(
        (_) => const SettingsStorageFailure(),
      );
  @override
  Future<Result<bool, SettingsFailure>> requestNotifications() async =>
      (await _permissions.request()).mapErr(
        (_) => const SettingsStorageFailure(),
      );
  @override
  Future<Result<void, SettingsFailure>> openNotificationSettings() async =>
      (await _permissions.openSystemSettings()).mapErr(
        (_) => const SettingsStorageFailure(),
      );
  @override
  Future<Result<void, SettingsFailure>> setInterval(
    BackgroundSyncInterval value,
  ) async {
    final generation = ++_generation;
    final previous = _pendingWrite;
    final finished = Completer<void>();
    _pendingWrite = finished.future;
    try {
      await previous;
      if (generation != _generation) return const Ok(null);
      final result = await _intervals.write(value);
      if (result is Err) {
        log.warning('Background interval persistence failed');
        return const Err(SettingsStorageFailure());
      }
    } finally {
      // Platform scheduling must not delay persistence of a newer opt-out.
      finished.complete();
    }
    if (generation != _generation) return const Ok(null);
    try {
      await _schedule();
      log.config('Background interval saved=${value.name}');
      return const Ok(null);
    } on Exception {
      log.warning('Background schedule update failed');
      return const Err(SettingsStorageFailure());
    }
  }
}

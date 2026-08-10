import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';

class FailedUnlockAttemptsRepository {
  final KeyValueStorageDatasource<String> _storage;

  static const _failedUnlockAttemptsKey = 'failedUnlockAttemptsKey';
  static const _lockedUntilKey = 'unlockLockedUntilKey';

  FailedUnlockAttemptsRepository(this._storage);

  Future<Result<void, AppUnlockFailure>> setFailedUnlockAttempts(
    int attempts,
  ) async {
    try {
      await _storage.saveValue(
        key: _failedUnlockAttemptsKey,
        value: attempts.toString(),
      );
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to save unlock attempts',
        error: e,
        trace: st,
      );
      return Err(AppUnlockUnexpectedFailure(e.toString()));
    }
  }

  Future<Result<int, AppUnlockFailure>> getFailedUnlockAttempts() async {
    try {
      final timeout = await _storage.getValue(_failedUnlockAttemptsKey);
      return Ok(int.tryParse(timeout ?? '0') ?? 0);
    } catch (e, st) {
      log.severe(message: 'Failed to get unlock attempts', error: e, trace: st);
      return Err(AppUnlockUnexpectedFailure(e.toString()));
    }
  }

  /// Persists the wall-clock instant before which no unlock attempt may be
  /// verified. A counter alone cannot enforce a cooldown — it survives
  /// neither an app restart nor says anything about elapsed time — so the
  /// lockout is anchored to the clock. Pass null to clear it (on a
  /// successful unlock).
  Future<Result<void, AppUnlockFailure>> setLockedUntil(
    DateTime? lockedUntil,
  ) async {
    try {
      if (lockedUntil == null) {
        await _storage.deleteValue(_lockedUntilKey);
      } else {
        await _storage.saveValue(
          key: _lockedUntilKey,
          value: lockedUntil.millisecondsSinceEpoch.toString(),
        );
      }
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'Failed to save unlock lockout timestamp',
        error: e,
        trace: st,
      );
      return Err(AppUnlockUnexpectedFailure(e.toString()));
    }
  }

  Future<Result<DateTime?, AppUnlockFailure>> getLockedUntil() async {
    try {
      final raw = await _storage.getValue(_lockedUntilKey);
      final epoch = raw == null ? null : int.tryParse(raw);
      return Ok(
        epoch == null ? null : DateTime.fromMillisecondsSinceEpoch(epoch),
      );
    } catch (e, st) {
      log.severe(
        message: 'Failed to get unlock lockout timestamp',
        error: e,
        trace: st,
      );
      return Err(AppUnlockUnexpectedFailure(e.toString()));
    }
  }
}

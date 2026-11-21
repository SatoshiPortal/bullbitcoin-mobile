import 'package:secrets/secrets.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';

class FailedUnlockAttemptsRepository {
  final AccessKeychain _storage;

  FailedUnlockAttemptsRepository(this._storage);

  Future<Result<void, AppUnlockFailure>> setFailedUnlockAttempts(
    int attempts,
  ) async {
    try {
      final result = await _storage.writeAttempts(attempts.toString());
      if (result case Err(:final failure)) {
        return Err(AppUnlockUnexpectedFailure(failure.logMessage));
      }
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
      final result = await _storage.readAttempts();
      if (result case Err(:final failure)) {
        return Err(AppUnlockUnexpectedFailure(failure.logMessage));
      }
      final timeout = (result as Ok<String?, SecretFailure>).value;
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
        final result = await _storage.deleteLockedUntil();
        if (result case Err(:final failure)) {
          return Err(AppUnlockUnexpectedFailure(failure.logMessage));
        }
      } else {
        final result = await _storage.writeLockedUntil(
          lockedUntil.millisecondsSinceEpoch.toString(),
        );
        if (result case Err(:final failure)) {
          return Err(AppUnlockUnexpectedFailure(failure.logMessage));
        }
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
      final result = await _storage.readLockedUntil();
      if (result case Err(:final failure)) {
        return Err(AppUnlockUnexpectedFailure(failure.logMessage));
      }
      final raw = (result as Ok<String?, SecretFailure>).value;
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

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';

class FailedUnlockAttemptsRepository {
  final KeyValueStorageDatasource<String> _storage;

  static const _failedUnlockAttemptsKey = 'failedUnlockAttemptsKey';

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
}

import 'package:bb_mobile/core/data/datasources/key_value_stores/key_value_storage_data_source.dart';
import 'package:bb_mobile/features/app_unlock/domain/repositories/failed_unlock_attempts_repository.dart';

class FailedUnlockAttemptsRepositoryImpl
    implements FailedUnlockAttemptsRepository {
  final KeyValueStorageDataSource<String> _storage;

  static const _failedUnlockAttemptsKey = 'failedUnlockAttemptsKey';

  FailedUnlockAttemptsRepositoryImpl(this._storage);

  @override
  Future<void> setFailedUnlockAttempts(int attempts) async {
    await _storage.saveValue(
      key: _failedUnlockAttemptsKey,
      value: attempts.toString(),
    );
  }

  @override
  Future<int> getFailedUnlockAttempts() async {
    final timeout = await _storage.getValue(_failedUnlockAttemptsKey);

    return int.tryParse(timeout ?? '0') ?? 0;
  }
}

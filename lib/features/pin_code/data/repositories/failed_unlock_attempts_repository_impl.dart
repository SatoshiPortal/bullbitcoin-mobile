import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';

class FailedUnlockAttemptsRepository {
  final KeyValueStorageDatasource<String> _storage;

  static const _failedUnlockAttemptsKey = 'failedUnlockAttemptsKey';

  FailedUnlockAttemptsRepository(this._storage);

  Future<void> setFailedUnlockAttempts(int attempts) async {
    await _storage.saveValue(
      key: _failedUnlockAttemptsKey,
      value: attempts.toString(),
    );
  }

  Future<int> getFailedUnlockAttempts() async {
    final timeout = await _storage.getValue(_failedUnlockAttemptsKey);

    return int.tryParse(timeout ?? '0') ?? 0;
  }
}

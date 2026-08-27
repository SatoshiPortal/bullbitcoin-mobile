import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/wallet_backup/data/models/wallet_backup_recovery_outcome_model.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery_outcome.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_recovery_outcome_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:primitives/primitives.dart';

final class WalletBackupRecoveryOutcomeRepositoryImpl
    implements WalletBackupRecoveryOutcomeRepository {
  static const _key = 'walletBackupLastRecoveryOutcome';

  final KeyValueStorageDatasource<String> _storage;

  const WalletBackupRecoveryOutcomeRepositoryImpl(this._storage);

  @override
  Future<Result<void, WalletBackupFailure>> save(
    WalletBackupRecoveryOutcome outcome,
  ) async {
    try {
      await _storage.saveValue(
        key: _key,
        value: WalletBackupRecoveryOutcomeModel.fromDomain(outcome).encode(),
      );
      return const Ok(null);
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to save wallet backup recovery outcome',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(WalletBackupStorageFailure('save recovery outcome'));
    }
  }

  @override
  Future<Result<WalletBackupRecoveryOutcome?, WalletBackupFailure>>
  read() async {
    try {
      final encoded = await _storage.getValue(_key);
      if (encoded == null) return const Ok(null);
      return Ok(
        WalletBackupRecoveryOutcomeModel.tryDecode(encoded)?.toDomain(),
      );
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to read wallet backup recovery outcome',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(WalletBackupStorageFailure('read recovery outcome'));
    }
  }
}

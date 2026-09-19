import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

abstract interface class WalletBackupStateRepository {
  Stream<void> get changes;

  @useResult
  Future<Result<WalletBackupState, WalletBackupFailure>> get(String identity);

  @useResult
  Future<Result<void, WalletBackupFailure>> setEnabled(
    bool enabled, {
    bool onlyIfUndecided = false,
  });

  @useResult
  Future<Result<WalletBackupControl, WalletBackupFailure>> getControl();

  @useResult
  Future<Result<void, WalletBackupFailure>> setRecoveryIncomplete(
    bool incomplete, {
    bool vaultOnly = false,
  });

  @useResult
  Future<Result<void, WalletBackupFailure>> recordPublication({
    required String identity,
    required String? expectedEtag,
    required WalletBackupCheckpoint checkpoint,
    required String contentHash,
    required DateTime succeededAt,
  });

  @useResult
  Future<Result<void, WalletBackupFailure>> clearRemoteCheckpoint({
    required String identity,
    required String expectedEtag,
  });
}

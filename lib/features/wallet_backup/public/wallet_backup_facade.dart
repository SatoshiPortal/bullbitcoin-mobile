import 'package:bb_mobile/features/wallet_backup/watchers/wallet_backup_watcher.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_inspection.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/inspect_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/manage_wallet_backup_state_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/manage_bullvault_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/vault_backup_recovery.dart';

export '../domain/entities/vault_backup_recovery.dart';
export '../domain/entities/bullvault_backup_entry.dart';
export '../domain/entities/wallet_backup_inspection.dart';
export '../domain/entities/wallet_backup_recovery.dart';
export '../domain/entities/wallet_inventory_recovery.dart';
export '../domain/entities/wallet_backup_remote_head.dart';
export '../domain/entities/wallet_backup_snapshot.dart';
export '../domain/entities/wallet_backup_state.dart';
export '../domain/wallet_backup_failure.dart';

class WalletBackupFacade {
  final GetWalletBackupControlUsecase _getControl;
  final InspectWalletBackupUsecase _inspect;
  final RecoverWalletBackupUsecase _recover;
  final RestoreBullVaultBackupUsecase _recoverVaults;

  final WatchWalletBackupStateUsecase _watchState;
  final WalletBackupWatcher _watcher;

  const WalletBackupFacade({
    required this._getControl,
    required this._inspect,
    required this._recover,
    required this._recoverVaults,
    required this._watchState,
    required this._watcher,
  });

  Stream<void> watchState() => _watchState.execute();
  void resumeAutomatic() => _watcher.resume();
  Future<void> stopAutomatic() => _watcher.stop();

  @useResult
  Future<Result<VaultBackupRecovery?, WalletBackupFailure>> recoverVaults({
    String? words,
    bool Function()? abandoned,
  }) => _recoverVaults.execute(words: words, abandoned: abandoned);

  @useResult
  Future<Result<WalletBackupRecovery, WalletBackupFailure>> recover(
    WalletBackupInspection inspection, {
    bool enableAfterRecovery = false,
  }) => _recover.execute(inspection, enableAfterRecovery: enableAfterRecovery);

  @useResult
  Future<Result<WalletBackupControl, WalletBackupFailure>> getControl() =>
      _getControl.execute();

  @useResult
  Future<Result<WalletBackupInspection, WalletBackupFailure>> inspect() =>
      _inspect.execute();
}

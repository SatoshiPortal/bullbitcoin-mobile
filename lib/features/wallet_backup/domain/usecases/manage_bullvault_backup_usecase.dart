import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_diagnostics.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/vault_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_inspection.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_inventory_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/inspect_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_operation_queue.dart';
import 'package:meta/meta.dart';

/// Reuses the native vault importer without applying the rest of the snapshot.
final class RestoreBullVaultBackupUsecase {
  final WalletInventoryBackupRepository _repository;
  final WalletBackupStateRepository _state;
  final WalletBackupOperationQueue _operations;
  final InspectWalletBackupUsecase _inspect;
  const RestoreBullVaultBackupUsecase({
    required this._repository,
    required this._state,
    required this._operations,
    required this._inspect,
  });

  @useResult
  Future<Result<VaultBackupRecovery?, WalletBackupFailure>> execute({
    String? words,
    bool Function()? abandoned,
  }) => _operations.run(() async {
    if (abandoned?.call() ?? false) return const Ok(null);
    final fetched = await _inspect.execute(words: words);
    if (fetched case Err(:final failure)) return Err(failure);
    if (abandoned?.call() ?? false) return const Ok(null);
    final inspection =
        (fetched as Ok<WalletBackupInspection, WalletBackupFailure>).value;
    final snapshot = inspection.snapshot;
    if (snapshot == null || snapshot.vaults.isEmpty) {
      return Ok(
        VaultBackupRecovery(
          inspection: inspection,
          wallets: WalletInventoryRecovery(
            walletReferences: {},
            failedReferences: [],
          ),
        ),
      );
    }
    if (await _state.setRecoveryIncomplete(true, vaultOnly: true) case Err(
      :final failure,
    )) {
      return Err(failure);
    }
    final restored = await _repository.restoreVaults(
      snapshot.vaults,
      snapshot.manifest.wallets,
      abandoned: abandoned,
    );
    final WalletInventoryRecovery wallets;
    WalletBackupFailure? failure;
    switch (restored) {
      case Err(failure: final error):
        failure = error;
        wallets = WalletInventoryRecovery(
          walletReferences: {},
          failedReferences: snapshot.vaults
              .map((entry) => entry.reference)
              .toList(),
        );
      case Ok(:final value):
        wallets = value;
    }
    // A vault-only recovery cannot clear an earlier incomplete full recovery.
    if (wallets.complete && failure == null) {
      if (await _state.setRecoveryIncomplete(false, vaultOnly: true) case Err(
        failure: final error,
      )) {
        failure = error;
      }
    }
    return Ok(
      VaultBackupRecovery(
        inspection: inspection,
        wallets: wallets,
        failure: failure,
      ),
    );
  }, name: WalletBackupOperation.recoverVaults);
}

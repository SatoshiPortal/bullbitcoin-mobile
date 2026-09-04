import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_restore_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/can_delete_bullvault_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/restore_bullvault_usecase.dart';
import 'package:meta/meta.dart';

export 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
export 'package:bb_mobile/features/bullvault/domain/entities/bullvault_details.dart';
export 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
export 'package:bb_mobile/features/bullvault/domain/entities/bullvault_previous_vault.dart';
export 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
export 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
export 'package:bb_mobile/features/bullvault/domain/entities/bullvault_restore_result.dart';
export 'package:bb_mobile/features/bullvault/public/bullvault_contributions.dart';
export 'package:bb_mobile/features/bullvault/ui/bullvault_recovery_package_share.dart'
    show shareBullVaultRecoveryPackage;
export 'package:bb_mobile/features/bullvault/ui/bullvault_router.dart'
    show BullVaultRouter;

class BullVaultFacade {
  static const createRouteName = 'bullVaultCreate';
  static const restoreRouteName = 'bullVaultRestore';
  static const settingsRouteName = 'bullVaultSettings';

  final CanDeleteBullVaultWalletUsecase _canDeleteWalletUsecase;
  final BullVaultRepository _repository;
  final RestoreBullVaultUsecase _restoreUsecase;

  const BullVaultFacade(
    this._canDeleteWalletUsecase,
    this._repository,
    this._restoreUsecase,
  );

  /// Every vault record on this device, for the backup's vaults section.
  @useResult
  Future<Result<List<BullVaultRecord>, BullVaultFailure>> listRecords() =>
      _repository.getAll();

  /// The recovery package exactly as the vault feature shares it.
  String encodeRecoveryPackage(BullVaultRecoveryPackage package) =>
      _repository.encodeRecoveryPackage(package);

  /// Structural read of a recovery package; null when it is not one. Does not
  /// check that the mobile key derives from a local seed — restore does.
  BullVaultRecoveryPackage? decodeRecoveryPackage(String source) =>
      switch (_repository.decodeRecoveryPackage(source)) {
        Ok(:final value) => value,
        Err() => null,
      };

  /// Restores a vault from its recovery package, creating the wallet if it is
  /// absent and accepting a matching wallet that already exists.
  @useResult
  Future<Result<BullVaultRestoreResult, BullVaultFailure>>
  restoreFromRecoveryPackage({required String source, required String label}) =>
      _restoreUsecase.execute(
        kind: BullVaultRestoreInputKind.recoveryPackage,
        source: source,
        label: label,
      );

  @useResult
  Future<Result<bool, BullVaultFailure>> isBullVaultWallet(
    String walletId,
  ) async => switch (await _canDeleteWalletUsecase.execute(walletId)) {
    Ok(:final value) => Ok(!value),
    Err(:final failure) => Err(failure),
  };

  @useResult
  Future<Result<bool, BullVaultFailure>> canDeleteWallet(String walletId) =>
      _canDeleteWalletUsecase.execute(walletId);
}

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/can_delete_bullvault_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/reconcile_bullvault_visibility_usecase.dart';
import 'package:meta/meta.dart';

export 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
export 'package:bb_mobile/features/bullvault/public/bullvault_contributions.dart';
export 'package:bb_mobile/features/bullvault/ui/bullvault_router.dart'
    show BullVaultRouter;

class BullVaultFacade {
  static const createRouteName = 'bullVaultCreate';
  static const restoreRouteName = 'bullVaultRestore';
  static const settingsRouteName = 'bullVaultSettings';

  final CanDeleteBullVaultWalletUsecase _canDeleteWalletUsecase;
  final ReconcileBullVaultVisibilityUsecase _reconcileVisibilityUsecase;

  const BullVaultFacade(
    this._canDeleteWalletUsecase,
    this._reconcileVisibilityUsecase,
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

  @useResult
  Future<Result<void, BullVaultFailure>> reconcileVisibility() =>
      _reconcileVisibilityUsecase.execute();
}

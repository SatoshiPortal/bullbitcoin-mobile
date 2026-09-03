import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/reserve_bip48_account_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/set_wallet_hidden_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:meta/meta.dart';

class ResumeBullVaultOnboardingUsecase {
  final BullVaultRepository _repository;
  final GetWalletUsecase _getWalletUsecase;
  final SetWalletHiddenUsecase _setWalletHiddenUsecase;
  final ReserveBip48AccountUsecase _reserveBip48AccountUsecase;

  const ResumeBullVaultOnboardingUsecase(
    this._repository,
    this._getWalletUsecase,
    this._setWalletHiddenUsecase,
    this._reserveBip48AccountUsecase,
  );

  @useResult
  Future<Result<BullVaultCreateResult?, BullVaultFailure>> execute(
    Network network, {
    String? walletId,
  }) async {
    final loaded = walletId == null
        ? await _repository.getIncompleteInitial(network)
        : await _repository.getByWalletId(walletId);
    late BullVaultRecord? record;
    switch (loaded) {
      case Ok(:final value):
        record = value;
      case Err(:final failure):
        return Err(failure);
    }
    if (record == null) return const Ok(null);
    if (walletId != null &&
        record.status == BullVaultLifecycleStatus.migrating) {
      return const Err(BullVaultCreationFailure());
    }

    try {
      final wallet = await _getWalletUsecase.execute(record.walletId);
      if (wallet == null) return const Err(BullVaultCreationFailure());
      final recoveryPackage = record.recoveryPackage;
      if (recoveryPackage.policy.network != network) {
        return const Err(BullVaultCreationFailure());
      }
      final mobileSeedFingerprint = record.mobileSeedFingerprint;
      if (mobileSeedFingerprint != null) {
        final reserved = await _reserveBip48AccountUsecase.execute(
          seedFingerprint: mobileSeedFingerprint,
          coinType: network.coinType,
          account: record.mobileAccount!,
        );
        if (reserved case Err()) {
          return const Err(BullVaultCreationFailure());
        }
      }
      if (record.status == BullVaultLifecycleStatus.activating) {
        await _setWalletHiddenUsecase.execute(
          walletId: wallet.id,
          isHidden: false,
        );
        final active = record.copyWith(status: BullVaultLifecycleStatus.active);
        switch (await _repository.save(active)) {
          case Ok():
            record = active;
          case Err(:final failure):
            try {
              await _setWalletHiddenUsecase.execute(
                walletId: wallet.id,
                isHidden: true,
              );
            } on Exception {
              // The activating record remains available for another retry.
            }
            return Err(failure);
        }
      }
      return Ok(BullVaultCreateResult(wallet: wallet, record: record));
    } on Exception {
      return const Err(BullVaultCreationFailure());
    }
  }
}

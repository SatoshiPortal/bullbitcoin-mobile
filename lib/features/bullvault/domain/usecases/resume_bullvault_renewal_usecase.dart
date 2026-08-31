import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/set_wallet_hidden_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_renew_result.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:meta/meta.dart';

class ResumeBullVaultRenewalUsecase {
  final BullVaultRepository _repository;
  final GetWalletUsecase _getWalletUsecase;
  final SetWalletHiddenUsecase _setWalletHiddenUsecase;

  const ResumeBullVaultRenewalUsecase(
    this._repository,
    this._getWalletUsecase,
    this._setWalletHiddenUsecase,
  );

  @useResult
  Future<Result<BullVaultRenewResult?, BullVaultFailure>> execute(
    String walletId,
  ) async {
    final currentResult = await _repository.getByWalletId(walletId);
    late BullVaultRecord current;
    switch (currentResult) {
      case Ok(value: final value?):
        current = value;
      case Ok(value: null):
        return const Ok(null);
      case Err(:final failure):
        return Err(failure);
    }
    if (current.status == BullVaultLifecycleStatus.cancelled ||
        (current.vaultGeneration == 0 &&
            current.status != BullVaultLifecycleStatus.active)) {
      return const Ok(null);
    }
    if (current.status == BullVaultLifecycleStatus.pending ||
        current.status == BullVaultLifecycleStatus.activating) {
      final previousId = current.previousVaultId;
      if (previousId == null) return const Err(BullVaultRenewalFailure());
      switch (await _repository.getByWalletId(previousId)) {
        case Ok(value: final previous?)
            when previous.status == BullVaultLifecycleStatus.active ||
                previous.status == BullVaultLifecycleStatus.migrating:
          current = previous;
        case _:
          return const Err(BullVaultRenewalFailure());
      }
    } else if (current.status != BullVaultLifecycleStatus.active &&
        current.status != BullVaultLifecycleStatus.migrating) {
      return const Err(BullVaultRenewalFailure());
    }
    final lineageResult = await _repository.getLineage(current.lineageId);
    late final List<BullVaultRecord> lineage;
    switch (lineageResult) {
      case Ok(:final value):
        lineage = value;
      case Err(:final failure):
        return Err(failure);
    }
    final linkedSuccessors = lineage.where(
      (record) =>
          record.status == BullVaultLifecycleStatus.active &&
          record.recoveryPackageConfirmed &&
          record.previousVaultId != null,
    );
    final linkedSuccessor = switch (current.status) {
      BullVaultLifecycleStatus.migrating =>
        linkedSuccessors
            .where((record) => record.previousVaultId == current.walletId)
            .singleOrNull,
      BullVaultLifecycleStatus.active => current,
      _ => null,
    };
    final linkedPrevious = linkedSuccessor == null
        ? null
        : lineage
              .where(
                (record) =>
                    record.walletId == linkedSuccessor.previousVaultId &&
                    record.status == BullVaultLifecycleStatus.migrating &&
                    record.successorWalletId == linkedSuccessor.walletId,
              )
              .singleOrNull;
    if (linkedPrevious != null) {
      try {
        final successorWallet = await _getWalletUsecase.execute(
          linkedSuccessor!.walletId,
        );
        final previousWallet = await _getWalletUsecase.execute(
          linkedPrevious.walletId,
        );
        if (successorWallet == null || previousWallet == null) {
          return const Err(BullVaultRenewalFailure());
        }
        await _setVisibility(
          visibleWallet: successorWallet,
          hiddenWallet: previousWallet,
        );
        return const Ok(null);
      } on Exception {
        return const Err(BullVaultRenewalFailure());
      }
    }
    final replacements = lineage
        .where(
          (record) =>
              (record.status == BullVaultLifecycleStatus.pending ||
                  record.status == BullVaultLifecycleStatus.activating) &&
              record.previousVaultId == current.walletId,
        )
        .toList();
    if (replacements.isEmpty) {
      if (current.status == BullVaultLifecycleStatus.active) {
        try {
          final wallet = await _getWalletUsecase.execute(current.walletId);
          if (wallet == null) return const Err(BullVaultRenewalFailure());
          if (wallet.isHidden) {
            await _setWalletHiddenUsecase.execute(
              walletId: wallet.id,
              isHidden: false,
            );
          }
        } on Exception {
          return const Err(BullVaultRenewalFailure());
        }
      }
      return const Ok(null);
    }
    if (replacements.length > 1) {
      return const Err(BullVaultRenewalFailure());
    }

    try {
      final replacement = replacements.single;
      final wallet = await _getWalletUsecase.execute(replacement.walletId);
      if (wallet == null) return const Err(BullVaultRenewalFailure());
      final recovery = replacement.recoveryPackage;
      final policy = recovery.policy;
      if (recovery.previousVaultId != current.walletId ||
          policy.lineageId != current.lineageId ||
          policy.vaultGeneration != replacement.vaultGeneration ||
          policy.descriptor != wallet.publicDescriptor ||
          policy.network != wallet.network) {
        return const Err(BullVaultRenewalFailure());
      }
      final currentWallet = await _getWalletUsecase.execute(current.walletId);
      if (currentWallet == null) return const Err(BullVaultRenewalFailure());
      if (replacement.status == BullVaultLifecycleStatus.pending) {
        await _setVisibility(
          visibleWallet: currentWallet,
          hiddenWallet: wallet,
        );
      } else {
        await _setVisibility(
          visibleWallet: wallet,
          hiddenWallet: currentWallet,
        );
      }
      return Ok(
        BullVaultRenewResult(
          previous: current,
          replacement: BullVaultCreateResult(
            wallet: wallet,
            policy: policy,
            record: replacement,
            recoveryPackage: recovery,
          ),
        ),
      );
    } on Exception {
      return const Err(BullVaultRenewalFailure());
    }
  }

  Future<void> _setVisibility({
    required Wallet visibleWallet,
    required Wallet hiddenWallet,
  }) async {
    final showVisibleWallet = visibleWallet.isHidden;
    final hideHiddenWallet = !hiddenWallet.isHidden;
    if (showVisibleWallet) {
      await _setWalletHiddenUsecase.execute(
        walletId: visibleWallet.id,
        isHidden: false,
      );
    }
    try {
      if (hideHiddenWallet) {
        await _setWalletHiddenUsecase.execute(
          walletId: hiddenWallet.id,
          isHidden: true,
        );
      }
    } on Exception {
      if (showVisibleWallet) {
        await _setWalletHiddenUsecase.execute(
          walletId: visibleWallet.id,
          isHidden: true,
        );
      }
      rethrow;
    }
  }
}

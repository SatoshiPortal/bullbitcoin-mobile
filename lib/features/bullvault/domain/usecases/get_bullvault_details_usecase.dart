import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_details.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_previous_vault.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:meta/meta.dart';

class GetBullVaultDetailsUsecase {
  final BullVaultRepository _repository;
  final GetWalletUsecase _getWalletUsecase;
  final GetAddressAtIndexUsecase _getAddressAtIndexUsecase;
  final DateTime Function() _clock;

  const GetBullVaultDetailsUsecase(
    this._repository,
    this._getWalletUsecase,
    this._getAddressAtIndexUsecase, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  @useResult
  Future<Result<BullVaultDetails?, BullVaultFailure>> execute(
    String walletId,
  ) async {
    final result = await _repository.getByWalletId(walletId);
    switch (result) {
      case Ok(value: null):
        return const Ok(null);
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final record?):
        try {
          final lineageResult = await _repository.getLineage(record.lineageId);
          late final List<BullVaultRecord> lineage;
          switch (lineageResult) {
            case Ok(:final value):
              lineage = value;
            case Err(:final failure):
              return Err(failure);
          }
          final activeRecords =
              lineage
                  .where(
                    (candidate) =>
                        candidate.status == BullVaultLifecycleStatus.active,
                  )
                  .toList()
                ..sort(
                  (first, second) =>
                      second.vaultGeneration.compareTo(first.vaultGeneration),
                );
          final active = activeRecords.isEmpty ? record : activeRecords.first;
          final previousVaults = <BullVaultPreviousVault>[];
          for (final candidate in lineage) {
            if (candidate.status != BullVaultLifecycleStatus.migrating &&
                candidate.status != BullVaultLifecycleStatus.cancelled) {
              continue;
            }
            final wallet = await _getWalletUsecase.execute(candidate.walletId);
            if (wallet == null) continue;
            if (candidate.status == BullVaultLifecycleStatus.cancelled &&
                wallet.balanceSat == BigInt.zero) {
              continue;
            }
            previousVaults.add(
              BullVaultPreviousVault(record: candidate, wallet: wallet),
            );
          }
          previousVaults.sort(
            (first, second) => second.record.vaultGeneration.compareTo(
              first.record.vaultGeneration,
            ),
          );
          final migrationAddress = previousVaults.isNotEmpty
              ? await _getAddressAtIndexUsecase.execute(
                  walletId: active.walletId,
                  index: 0,
                )
              : null;
          final policy = active.recoveryPackage.policy;
          final activations = <int>[
            ?policy.coldActivationTimestamp,
            ?policy.recoveryActivationTimestamp,
            ?policy.inheritanceActivationTimestamp,
          ];
          final firstActivation = activations.isEmpty
              ? null
              : activations.reduce(
                  (first, second) => first < second ? first : second,
                );
          final now = _clock().toUtc();
          final activation = firstActivation == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  firstActivation * 1000,
                  isUtc: true,
                );
          final remaining = activation?.difference(now);
          final original = policy.createdAt == null
              ? null
              : activation?.difference(policy.createdAt!);
          return Ok(
            BullVaultDetails(
              record: active,
              policy: policy,
              timeUntilFirstRecovery: remaining?.isNegative == true
                  ? Duration.zero
                  : remaining,
              showEarlyRenewalWarning:
                  remaining != null &&
                  original != null &&
                  remaining >
                      Duration(microseconds: original.inMicroseconds ~/ 2),
              migrationAddress: migrationAddress?.address,
              previousVaults: previousVaults,
            ),
          );
        } on Exception {
          return const Err(BullVaultRenewalFailure());
        }
    }
  }
}

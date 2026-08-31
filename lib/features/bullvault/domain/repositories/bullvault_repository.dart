import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:meta/meta.dart';

abstract interface class BullVaultRepository {
  Result<BullVaultRecoveryPackage, BullVaultFailure> decodeRecoveryPackage(
    String source,
  );

  String encodeRecoveryPackage(BullVaultRecoveryPackage recoveryPackage);

  @useResult
  Future<Result<int, BullVaultFailure>> reserveNextGeneration(
    BullVaultRecord current,
  );

  @useResult
  Future<Result<void, BullVaultFailure>> releaseGeneration({
    required String lineageId,
    required int generation,
  });

  @useResult
  Future<Result<BullVaultRecord?, BullVaultFailure>> getByWalletId(
    String walletId,
  );

  @useResult
  Future<Result<List<BullVaultRecord>, BullVaultFailure>> getLineage(
    String lineageId,
  );

  @useResult
  Future<Result<BullVaultRecord?, BullVaultFailure>> getIncompleteInitial(
    Network network,
  );

  @useResult
  Future<Result<void, BullVaultFailure>> save(BullVaultRecord record);

  @useResult
  Future<Result<void, BullVaultFailure>> delete(String walletId);

  @useResult
  Future<Result<void, BullVaultFailure>> activateRenewal({
    required BullVaultRecord previous,
    required BullVaultRecord replacement,
  });

  @useResult
  Future<Result<void, BullVaultFailure>> linkRestoredRenewal({
    required BullVaultRecord previous,
    required BullVaultRecord successor,
  });

  @useResult
  Future<Result<void, BullVaultFailure>> cancelRenewal({
    required String previousWalletId,
    required String replacementWalletId,
  });
}

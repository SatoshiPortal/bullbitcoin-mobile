import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:meta/meta.dart';

abstract interface class BullVaultRepository {
  @useResult
  Future<Result<String?, BullVaultFailure>> pickRecoveryFile();

  /// Initial state and committed changes to the vault backup contribution.
  Stream<void> watchBackupChanges();

  Result<BullVaultRecoveryPackage, BullVaultFailure> decodeRecoveryPackage(
    String source,
  );

  String encodeRecoveryPackage(BullVaultRecoveryPackage recoveryPackage);

  /// Encrypts [descriptor] for every account it entrusts, so any one cosigner
  /// can recover the vault from the artifact alone.
  @useResult
  Result<BullVaultDescriptorBackup, BullVaultFailure>
  encodePrivateDescriptorBackup({
    required String descriptor,
    required Network network,
  });

  /// The alias an account key publishes under, or null when the input is not
  /// an account key. Accepts a bare xpub, an origin-qualified expression or a
  /// descriptor naming exactly one account.
  String? descriptorLookupToken(String accountKeyInput);

  /// Opens an artifact with one account key and proves the descriptor inside
  /// really names that exact account.
  @useResult
  Result<BullVaultDescriptorBackup, BullVaultFailure>
  decodePrivateDescriptorBackup({
    required Uint8List bytes,
    required String accountKeyInput,
  });

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

  /// Every vault record on this device, whatever its lifecycle status.
  @useResult
  Future<Result<List<BullVaultRecord>, BullVaultFailure>> getAll();

  @useResult
  Future<Result<List<BullVaultRecord>, BullVaultFailure>> getLineage(
    String lineageId,
  );

  @useResult
  Future<Result<List<BullVaultRecord>, BullVaultFailure>> getWalletLineage(
    String walletId, {
    String? memberWalletId,
  });

  @useResult
  Future<Result<BullVaultRecord?, BullVaultFailure>> getIncompleteInitial(
    Network network,
  );

  @useResult
  Future<Result<void, BullVaultFailure>> save(BullVaultRecord record);

  @useResult
  Future<Result<void, BullVaultFailure>> publishRestored(
    BullVaultRecord record,
  );

  @useResult
  Future<Result<void, BullVaultFailure>> delete(String walletId);

  @useResult
  Future<Result<void, BullVaultFailure>> activateInitial(
    BullVaultRecord record,
  );

  @useResult
  Future<Result<Map<String, String>, BullVaultFailure>>
  getMigrationDestinations(Set<String> walletIds);

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

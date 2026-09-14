import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_parser.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/encode_private_descriptor_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_restore_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/can_delete_bullvault_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/restore_bullvault_usecase.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/watch_bullvault_backup_changes_usecase.dart';

export 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
export 'package:bb_mobile/features/bullvault/domain/entities/bullvault_descriptor_backup.dart';
export 'package:bb_mobile/features/bullvault/domain/entities/bullvault_policy.dart';
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
  static const menuRouteName = 'bullVaultMenu';
  static const policyRouteName = 'bullVaultPolicy';
  static const keysRouteName = 'bullVaultKeys';
  static const backupRouteName = 'bullVaultBackupRecovery';
  static const renewRouteName = 'bullVaultRenew';
  static const importCosignerRouteName = 'bullVaultImportCosigner';

  final CanDeleteBullVaultWalletUsecase _canDeleteWalletUsecase;
  final BullVaultRepository _repository;
  final RestoreBullVaultUsecase _restoreUsecase;
  final WatchBullVaultBackupChangesUsecase _watchBackupChanges;
  final EncodePrivateDescriptorBackupUsecase _encodePrivateDescriptor;

  const BullVaultFacade(
    this._canDeleteWalletUsecase,
    this._repository,
    this._restoreUsecase,
    this._watchBackupChanges,
    this._encodePrivateDescriptor,
  );

  /// Initial wake-up and committed changes whose revisions are already saved.
  Stream<void> watchBackupChanges() => _watchBackupChanges.execute();

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

  /// Restores a vault from its bare descriptor, without the extra facts a
  /// recovery package carries. Every rule the package path applies still holds.
  @useResult
  Future<Result<BullVaultRestoreResult, BullVaultFailure>>
  restoreFromDescriptor({required String source, required String label}) =>
      _restoreUsecase.execute(
        kind: BullVaultRestoreInputKind.descriptor,
        source: source,
        label: label,
      );

  /// The vault's descriptor sealed for each of its cosigners, with the lookup
  /// alias each of them can find it under.
  @useResult
  Future<Result<BullVaultDescriptorBackup, BullVaultFailure>>
  encodePrivateDescriptorBackup(String walletId) =>
      _encodePrivateDescriptor.execute(walletId);

  /// Opens a private descriptor backup with one cosigner's account key, proving
  /// the descriptor inside names that exact account before returning it.
  @useResult
  Result<BullVaultDescriptorBackup, BullVaultFailure>
  decodePrivateDescriptorBackup({
    required Uint8List bytes,
    required String accountKeyInput,
  }) => _repository.decodePrivateDescriptorBackup(
    bytes: bytes,
    accountKeyInput: accountKeyInput,
  );

  /// The lookup alias an account key publishes under, or null when the input is
  /// not an account key. Accepts a bare xpub, an origin-qualified expression or
  /// a descriptor naming one account.
  String? descriptorLookupToken(String accountKeyInput) {
    try {
      return DescriptorBackupParser.inputKey(accountKeyInput).lookupToken;
    } on FormatException {
      return null;
    }
  }

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

import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_restore_result.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/restore_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/get_bullvault_records_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/decode_bullvault_recovery_package_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/encode_bullvault_recovery_package_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/can_delete_bullvault_wallet_usecase.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/pick_bullvault_recovery_file_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/verify_bullvault_descriptor_backup_usecase.dart';

export 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
export 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
export 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
export 'package:bb_mobile/features/bullvault/domain/entities/bullvault_restore_result.dart';
export 'package:bb_mobile/features/bullvault/public/bullvault_contributions.dart';
export 'package:bb_mobile/features/bullvault/ui/bullvault_scanner_screen.dart'
    show BullVaultScannerScreen, BullVaultScannerPurpose;
export 'package:bb_mobile/features/bullvault/ui/bullvault_recovery_package_share.dart'
    show shareBullVaultRecoveryPackage;
export 'package:bb_mobile/features/bullvault/ui/bullvault_router.dart'
    show BullVaultRouter;

class BullVaultFacade {
  static const menuRouteName = 'bullVaultMenu';
  static const policyRouteName = 'bullVaultPolicy';
  static const keysRouteName = 'bullVaultKeys';
  static const backupRouteName = 'bullVaultBackup';
  static const renewRouteName = 'bullVaultRenew';
  static const createRouteName = 'bullVaultCreate';
  static const restoreRouteName = 'bullVaultRestore';
  static const descriptorRestoreRouteName = 'bullVaultDescriptorRestore';
  static const settingsRouteName = 'bullVaultSettings';
  static const cosignerRouteName = 'bullVaultCosigner';

  final CanDeleteBullVaultWalletUsecase _canDeleteWalletUsecase;

  final GetBullVaultRecordsUsecase _getRecords;
  final WatchBullVaultRecordsUsecase _watchRecords;
  final EncodeBullVaultRecoveryPackageUsecase _encodePackage;
  final DecodeBullVaultRecoveryPackageUsecase _decodePackage;
  final RestoreBullVaultUsecase _restore;
  final GetBullVaultRecordUsecase _getRecord;
  final VerifyBullVaultDescriptorBackupUsecase _verifyBackup;
  final PickBullVaultRecoveryFileUsecase _pickFile;

  const BullVaultFacade(
    this._canDeleteWalletUsecase,
    this._getRecords,
    this._watchRecords,
    this._encodePackage,
    this._decodePackage,
    this._restore,
    this._getRecord,
    this._verifyBackup,
    this._pickFile,
  );

  @useResult
  Future<Result<String?, BullVaultFailure>> pickRecoveryFile() =>
      _pickFile.execute();

  @useResult
  Future<Result<BullVaultRecord?, BullVaultFailure>> getRecord(
    String walletId,
  ) => _getRecord.execute(walletId);

  @useResult
  Future<Result<DateTime, BullVaultFailure>> verifyBackup({
    required BullVaultRecord expected,
    required String source,
    BullVaultBackupTestKind kind = BullVaultBackupTestKind.descriptor,
  }) => _verifyBackup.execute(expected: expected, source: source, kind: kind);

  @useResult
  Future<Result<List<BullVaultRecord>, BullVaultFailure>> listRecords() =>
      _getRecords.execute();

  Stream<void> watchRecords() => _watchRecords.execute();

  String encodeRecoveryPackage(BullVaultRecoveryPackage package) =>
      _encodePackage.execute(package);

  @useResult
  Result<BullVaultRecoveryPackage, BullVaultFailure> decodeRecoveryPackage(
    String source,
  ) => _decodePackage.execute(source);

  @useResult
  Future<Result<BullVaultRestoreResult, BullVaultFailure>>
  restoreFromRecoveryPackage({
    required String source,
    required String label,
    BullVaultLifecycleStatus? status,
    Network? network,
  }) => _restore.execute(
    kind: BullVaultRestoreInputKind.recoveryPackage,
    source: source,
    label: label,
    recoveredStatus: status,
    recoveredNetwork: network,
  );

  @useResult
  Future<Result<BullVaultRestoreResult, BullVaultFailure>>
  restoreFromDescriptor({required String source, required String label}) =>
      _restore.execute(
        kind: BullVaultRestoreInputKind.descriptor,
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

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

export 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
export 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
export 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
export 'package:bb_mobile/features/bullvault/domain/entities/bullvault_restore_result.dart';
export 'package:bb_mobile/features/bullvault/public/bullvault_contributions.dart';
export 'package:bb_mobile/features/bullvault/ui/bullvault_router.dart'
    show BullVaultRouter;

class BullVaultFacade {
  static const createRouteName = 'bullVaultCreate';
  static const restoreRouteName = 'bullVaultRestore';
  static const settingsRouteName = 'bullVaultSettings';

  final CanDeleteBullVaultWalletUsecase _canDeleteWalletUsecase;

  final GetBullVaultRecordsUsecase _getRecords;
  final WatchBullVaultRecordsUsecase _watchRecords;
  final EncodeBullVaultRecoveryPackageUsecase _encodePackage;
  final DecodeBullVaultRecoveryPackageUsecase _decodePackage;
  final RestoreBullVaultUsecase _restore;

  const BullVaultFacade(
    this._canDeleteWalletUsecase,
    this._getRecords,
    this._watchRecords,
    this._encodePackage,
    this._decodePackage,
    this._restore,
  );

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

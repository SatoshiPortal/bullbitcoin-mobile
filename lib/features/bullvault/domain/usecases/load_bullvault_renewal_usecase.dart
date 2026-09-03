import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_details.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_renew_result.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_time_reference.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/get_bullvault_details_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/check_bullvault_mobile_backups_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/prepare_bullvault_time_reference_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/resume_bullvault_renewal_usecase.dart';

final class BullVaultRenewalLoad {
  final BullVaultDetails details;
  final BullVaultRenewResult? renewal;
  final BullVaultTimeReference? timeReference;
  final bool needsInitialSetup;

  const BullVaultRenewalLoad({
    required this.details,
    this.renewal,
    this.timeReference,
    this.needsInitialSetup = false,
  });
}

class LoadBullVaultRenewalUsecase {
  final GetBullVaultDetailsUsecase _getDetailsUsecase;
  final ResumeBullVaultRenewalUsecase _resumeUsecase;
  final PrepareBullVaultTimeReferenceUsecase _prepareTimeReferenceUsecase;
  final CheckBullVaultMobileBackupsUsecase _checkMobileBackupsUsecase;

  const LoadBullVaultRenewalUsecase(
    this._getDetailsUsecase,
    this._resumeUsecase,
    this._prepareTimeReferenceUsecase,
    this._checkMobileBackupsUsecase,
  );

  Future<Result<BullVaultRenewalLoad, BullVaultFailure>> execute(
    String walletId,
  ) async {
    final detailsResult = await _getDetailsUsecase.execute(walletId);
    final BullVaultDetails details;
    switch (detailsResult) {
      case Ok(value: final value?):
        details = value;
      case Ok(value: null):
        return const Err(BullVaultRenewalFailure());
      case Err(:final failure):
        return Err(failure);
    }
    var needsInitialSetup = !details.record.hardwareSetupComplete;
    final mobileSeedFingerprint = details.record.mobileSeedFingerprint;
    if (mobileSeedFingerprint != null) {
      final backupStatus = await _checkMobileBackupsUsecase.execute(
        mobileSeedFingerprint,
      );
      needsInitialSetup =
          needsInitialSetup ||
          switch (backupStatus) {
            Ok(:final value) => !value.physical && !value.recoverBull,
            Err() => true,
          };
    }
    final resumed = await _resumeUsecase.execute(walletId);
    switch (resumed) {
      case Ok(value: final renewal?):
        return Ok(
          BullVaultRenewalLoad(
            details: details,
            renewal: renewal,
            needsInitialSetup: needsInitialSetup,
          ),
        );
      case Err(:final failure):
        return Err(failure);
      case Ok(value: null):
        break;
    }
    if (needsInitialSetup) {
      return Ok(
        BullVaultRenewalLoad(details: details, needsInitialSetup: true),
      );
    }
    final timeResult = await _prepareTimeReferenceUsecase.execute(
      isTestnet: details.policy.network.isTestnet,
    );
    return switch (timeResult) {
      Ok(:final value) => Ok(
        BullVaultRenewalLoad(
          details: details,
          timeReference: value,
          needsInitialSetup: needsInitialSetup,
        ),
      ),
      Err(:final failure) => Err(failure),
    };
  }
}

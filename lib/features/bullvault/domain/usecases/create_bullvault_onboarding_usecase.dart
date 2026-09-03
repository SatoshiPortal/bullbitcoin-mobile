import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_request.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_onboarding_snapshot.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/check_bullvault_mobile_backups_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/create_bullvault_usecase.dart';

class CreateBullVaultOnboardingUsecase {
  final CreateBullVaultUsecase _createUsecase;
  final CheckBullVaultMobileBackupsUsecase _checkMobileBackupsUsecase;

  const CreateBullVaultOnboardingUsecase(
    this._createUsecase,
    this._checkMobileBackupsUsecase,
  );

  Future<Result<BullVaultOnboardingSnapshot, BullVaultFailure>> execute(
    BullVaultCreateRequest request,
  ) async {
    final created = await _createUsecase.execute(request);
    switch (created) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final seedFingerprint = value.record.mobileSeedFingerprint;
        return Ok(
          BullVaultOnboardingSnapshot(
            result: value,
            mobileBackupStatus: seedFingerprint == null
                ? null
                : await _checkMobileBackupsUsecase.execute(seedFingerprint),
          ),
        );
    }
  }
}

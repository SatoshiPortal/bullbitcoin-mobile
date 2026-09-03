import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_onboarding_snapshot.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/check_bullvault_mobile_backups_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/resume_bullvault_onboarding_usecase.dart';

class LoadBullVaultOnboardingUsecase {
  final GetSettingsUsecase _getSettingsUsecase;
  final ResumeBullVaultOnboardingUsecase _resumeUsecase;
  final CheckBullVaultMobileBackupsUsecase _checkMobileBackupsUsecase;

  const LoadBullVaultOnboardingUsecase(
    this._getSettingsUsecase,
    this._resumeUsecase,
    this._checkMobileBackupsUsecase,
  );

  Future<Result<BullVaultOnboardingLoad, BullVaultFailure>> execute({
    String? walletId,
  }) async {
    try {
      final settings = await _getSettingsUsecase.execute();
      final network = Network.fromEnvironment(
        isTestnet: settings.environment.isTestnet,
        isLiquid: false,
      );
      final resumed = await _resumeUsecase.execute(network, walletId: walletId);
      return switch (resumed) {
        Ok(value: null) => Ok(BullVaultOnboardingLoad(network: network)),
        Ok(value: final result?) => Ok(
          BullVaultOnboardingLoad(
            network: network,
            snapshot: BullVaultOnboardingSnapshot(
              result: result,
              mobileBackupStatus: result.record.mobileSeedFingerprint == null
                  ? null
                  : await _checkMobileBackupsUsecase.execute(
                      result.record.mobileSeedFingerprint!,
                    ),
            ),
          ),
        ),
        Err(:final failure) => Err(failure),
      };
    } on Exception {
      return const Err(BullVaultCreationFailure());
    }
  }
}

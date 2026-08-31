import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_create_result.dart';

typedef BullVaultMobileBackupStatus = ({bool physical, bool recoverBull});

final class BullVaultOnboardingSnapshot {
  final BullVaultCreateResult result;
  final Result<BullVaultMobileBackupStatus, BullVaultFailure>?
  mobileBackupStatus;

  const BullVaultOnboardingSnapshot({
    required this.result,
    required this.mobileBackupStatus,
  });
}

final class BullVaultOnboardingLoad {
  final Network network;
  final BullVaultOnboardingSnapshot? snapshot;

  const BullVaultOnboardingLoad({required this.network, this.snapshot});
}

import 'package:bb_mobile/core/failures/failure.dart';

sealed class BullVaultFailure extends Failure {
  const BullVaultFailure([super.logMessage]);
}

final class BullVaultInvalidSignerFailure extends BullVaultFailure {
  const BullVaultInvalidSignerFailure([super.logMessage]);
}

final class BullVaultSignerReuseFailure extends BullVaultFailure {
  const BullVaultSignerReuseFailure([super.logMessage]);
}

final class BullVaultInvalidScheduleFailure extends BullVaultFailure {
  const BullVaultInvalidScheduleFailure([super.logMessage]);
}

final class BullVaultClockMismatchFailure extends BullVaultFailure {
  const BullVaultClockMismatchFailure([super.logMessage]);
}

final class BullVaultReviewExpiredFailure extends BullVaultFailure {
  const BullVaultReviewExpiredFailure([super.logMessage]);
}

final class BullVaultCreationFailure extends BullVaultFailure {
  const BullVaultCreationFailure([super.logMessage]);
}

final class BullVaultBackupStatusFailure extends BullVaultFailure {
  const BullVaultBackupStatusFailure([super.logMessage]);
}

final class BullVaultRenewalFailure extends BullVaultFailure {
  const BullVaultRenewalFailure([super.logMessage]);
}

final class BullVaultInvalidRecoveryFailure extends BullVaultFailure {
  const BullVaultInvalidRecoveryFailure([super.logMessage]);
}

import 'package:bb_mobile/core/failures/failure.dart';

sealed class WalletBackupFailure extends Failure {
  const WalletBackupFailure();
}

final class WalletBackupStorageFailure extends WalletBackupFailure {
  const WalletBackupStorageFailure();
}

final class WalletBackupChangedFailure extends WalletBackupFailure {
  const WalletBackupChangedFailure();
}

final class WalletBackupIncompleteFailure extends WalletBackupFailure {
  const WalletBackupIncompleteFailure();
}

final class WalletBackupInvalidFailure extends WalletBackupFailure {
  const WalletBackupInvalidFailure();
}

final class WalletBackupUnsupportedFailure extends WalletBackupFailure {
  const WalletBackupUnsupportedFailure();
}

final class WalletBackupTooLargeFailure extends WalletBackupFailure {
  const WalletBackupTooLargeFailure();
}

final class WalletBackupCredentialFailure extends WalletBackupFailure {
  const WalletBackupCredentialFailure();
}

final class WalletBackupNetworkFailure extends WalletBackupFailure {
  const WalletBackupNetworkFailure();
}

final class WalletBackupTimeoutFailure extends WalletBackupFailure {
  const WalletBackupTimeoutFailure();
}

final class WalletBackupConflictFailure extends WalletBackupFailure {
  const WalletBackupConflictFailure();
}

final class WalletBackupMissingFailure extends WalletBackupFailure {
  const WalletBackupMissingFailure();
}

final class WalletBackupConfirmationRequiredFailure
    extends WalletBackupFailure {
  const WalletBackupConfirmationRequiredFailure();
}

final class WalletBackupDeleteRequiresDisabledFailure
    extends WalletBackupFailure {
  const WalletBackupDeleteRequiresDisabledFailure();
}

final class WalletBackupRateLimitedFailure extends WalletBackupFailure {
  final DateTime retryAt;
  const WalletBackupRateLimitedFailure(this.retryAt);
}

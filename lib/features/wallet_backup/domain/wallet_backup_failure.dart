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

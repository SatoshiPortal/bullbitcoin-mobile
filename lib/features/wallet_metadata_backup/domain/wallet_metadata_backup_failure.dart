import 'package:bb_mobile/core/failures/failure.dart';

sealed class WalletMetadataBackupFailure extends Failure {
  const WalletMetadataBackupFailure([super.logMessage]);
}

final class WalletMetadataBackupStorageFailure
    extends WalletMetadataBackupFailure {
  const WalletMetadataBackupStorageFailure([super.logMessage]);
}

final class WalletMetadataBackupContributorFailure
    extends WalletMetadataBackupFailure {
  final String contributorType;

  const WalletMetadataBackupContributorFailure(this.contributorType)
    : super('Wallet metadata contributor failed');
}

final class WalletMetadataBackupKeyFailure extends WalletMetadataBackupFailure {
  const WalletMetadataBackupKeyFailure()
    : super('Wallet metadata key derivation failed');
}

final class WalletMetadataBackupEncodingFailure
    extends WalletMetadataBackupFailure {
  const WalletMetadataBackupEncodingFailure()
    : super('Wallet metadata snapshot encoding failed');
}

final class WalletMetadataBackupResourceLimitFailure
    extends WalletMetadataBackupFailure {
  const WalletMetadataBackupResourceLimitFailure()
    : super('Wallet metadata snapshot exceeds a resource limit');
}

final class WalletMetadataBackupRemoteFailure
    extends WalletMetadataBackupFailure {
  const WalletMetadataBackupRemoteFailure([super.logMessage]);
}

final class WalletMetadataBackupConflictFailure
    extends WalletMetadataBackupFailure {
  const WalletMetadataBackupConflictFailure()
    : super('Wallet metadata remote backup changed concurrently');
}

final class WalletMetadataBackupDeleteRequiresDisabledFailure
    extends WalletMetadataBackupFailure {
  const WalletMetadataBackupDeleteRequiresDisabledFailure()
    : super('Disable wallet metadata backup before deleting the remote copy');
}

final class WalletMetadataBackupUpdateRequiredFailure
    extends WalletMetadataBackupFailure {
  final int? envelopeVersion;

  const WalletMetadataBackupUpdateRequiredFailure({this.envelopeVersion})
    : super('Wallet metadata backup requires a newer app version');
}

final class WalletMetadataBackupClockFailure
    extends WalletMetadataBackupFailure {
  const WalletMetadataBackupClockFailure()
    : super('Wallet metadata publication clock or revision is exhausted');
}

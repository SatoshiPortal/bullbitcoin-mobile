import 'package:bb_mobile/core/failures/failure.dart';

sealed class WalletMetadataBackupFailure extends Failure {
  const WalletMetadataBackupFailure([super.logMessage]);
}

final class WalletMetadataBackupReadFailure
    extends WalletMetadataBackupFailure {
  const WalletMetadataBackupReadFailure()
    : super('Protected wallet data could not be read');
}

final class WalletMetadataBackupEncodingFailure
    extends WalletMetadataBackupFailure {
  const WalletMetadataBackupEncodingFailure()
    : super('Wallet metadata snapshot encoding failed');
}

final class WalletMetadataBackupWriteFailure
    extends WalletMetadataBackupFailure {
  const WalletMetadataBackupWriteFailure()
    : super('Protected wallet data could not be restored');
}

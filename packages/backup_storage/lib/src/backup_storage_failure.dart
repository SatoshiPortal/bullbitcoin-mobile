import 'package:primitives/primitives.dart';

sealed class BackupStorageFailure extends Failure {
  const BackupStorageFailure();
}

final class BackupStorageAuthorizationRequiredFailure
    extends BackupStorageFailure {
  const BackupStorageAuthorizationRequiredFailure();
}

final class BackupStorageCancelledFailure extends BackupStorageFailure {
  const BackupStorageCancelledFailure();
}

final class BackupStoragePermissionRevokedFailure extends BackupStorageFailure {
  const BackupStoragePermissionRevokedFailure();
}

final class BackupStorageQuotaExceededFailure extends BackupStorageFailure {
  const BackupStorageQuotaExceededFailure();
}

final class BackupStorageNotFoundFailure extends BackupStorageFailure {
  const BackupStorageNotFoundFailure();
}

final class BackupStorageTooLargeFailure extends BackupStorageFailure {
  const BackupStorageTooLargeFailure();
}

final class BackupStorageUnavailableFailure extends BackupStorageFailure {
  final bool retryable;

  const BackupStorageUnavailableFailure({this.retryable = true});
}

final class BackupStorageUnexpectedFailure extends BackupStorageFailure {
  const BackupStorageUnexpectedFailure();
}

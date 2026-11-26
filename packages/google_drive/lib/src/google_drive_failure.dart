import 'package:primitives/primitives.dart';

sealed class GoogleDriveFailure extends Failure {
  const GoogleDriveFailure();
}

final class GoogleDriveDisposedFailure extends GoogleDriveFailure {
  const GoogleDriveDisposedFailure();
}

final class GoogleDriveUnavailableFailure extends GoogleDriveFailure {
  const GoogleDriveUnavailableFailure();
}

final class GoogleDriveInvalidResponseFailure extends GoogleDriveFailure {
  const GoogleDriveInvalidResponseFailure();
}

final class GoogleDriveTooLargeFailure extends GoogleDriveFailure {
  const GoogleDriveTooLargeFailure();
}

final class GoogleDriveAuthorizationRequiredFailure extends GoogleDriveFailure {
  const GoogleDriveAuthorizationRequiredFailure();
}

final class GoogleDriveCancelledFailure extends GoogleDriveFailure {
  const GoogleDriveCancelledFailure();
}

final class GoogleDrivePermissionRevokedFailure extends GoogleDriveFailure {
  const GoogleDrivePermissionRevokedFailure();
}

final class GoogleDriveQuotaExceededFailure extends GoogleDriveFailure {
  const GoogleDriveQuotaExceededFailure();
}

final class GoogleDriveNotFoundFailure extends GoogleDriveFailure {
  const GoogleDriveNotFoundFailure();
}

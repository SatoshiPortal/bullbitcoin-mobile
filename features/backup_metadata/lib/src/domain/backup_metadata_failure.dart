import 'package:primitives/primitives.dart';

/// Recoverable data backup outcomes; translated in presentation only.
sealed class BackupMetadataFailure extends Failure {
  const BackupMetadataFailure();
}

/// The app database is not at the current schema yet (background run).
final class BackupMetadataNotReadyFailure extends BackupMetadataFailure {
  const BackupMetadataNotReadyFailure();
}

/// The merge plan was built from labels that changed since the preview.
final class BackupMetadataStalePlanFailure extends BackupMetadataFailure {
  const BackupMetadataStalePlanFailure();
}

/// A content exceeds the limits the reader accepts.
final class BackupMetadataTooLargeFailure extends BackupMetadataFailure {
  const BackupMetadataTooLargeFailure();
}

/// The view the operation started in is no longer the active one. Nothing
/// was published or applied.
final class BackupMetadataScopeChangedFailure extends BackupMetadataFailure {
  const BackupMetadataScopeChangedFailure();
}

/// The archive does not fit this phone's data (a conflicting BIP85 record, an
/// ambiguous public wallet). Nothing was written for that part.
final class BackupMetadataIncompatibleFailure extends BackupMetadataFailure {
  const BackupMetadataIncompatibleFailure();
}

/// The account behind the destination is not the one the user confirmed.
/// Nothing is sent until they reconnect and choose again.
final class BackupMetadataAccountChangedFailure extends BackupMetadataFailure {
  const BackupMetadataAccountChangedFailure();
}

final class BackupMetadataUnexpectedFailure extends BackupMetadataFailure {
  const BackupMetadataUnexpectedFailure();
}

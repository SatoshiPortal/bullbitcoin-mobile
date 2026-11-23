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

final class BackupMetadataUnexpectedFailure extends BackupMetadataFailure {
  const BackupMetadataUnexpectedFailure();
}

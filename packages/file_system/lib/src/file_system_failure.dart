import 'package:primitives/primitives.dart';

sealed class FileSystemFailure extends Failure {
  const FileSystemFailure([super.logMessage]);
}

final class FileSystemPickFailure extends FileSystemFailure {
  const FileSystemPickFailure([super.logMessage]);
}

final class FileSystemReadFailure extends FileSystemFailure {
  const FileSystemReadFailure([super.logMessage]);
}

final class FileSystemMissingFailure extends FileSystemFailure {
  const FileSystemMissingFailure();
}

final class FileSystemTooLargeFailure extends FileSystemFailure {
  const FileSystemTooLargeFailure();
}

final class FileSystemSaveFailure extends FileSystemFailure {
  const FileSystemSaveFailure([super.logMessage]);
}

final class FileSystemCleanupFailure extends FileSystemFailure {
  const FileSystemCleanupFailure([super.logMessage]);
}

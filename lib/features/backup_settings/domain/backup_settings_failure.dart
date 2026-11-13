import 'package:primitives/primitives.dart' show Failure;

sealed class BackupSettingsFailure extends Failure {
  const BackupSettingsFailure([super.logMessage]);
}

final class BackupSettingsUnexpectedFailure extends BackupSettingsFailure {
  const BackupSettingsUnexpectedFailure([super.logMessage]);
}

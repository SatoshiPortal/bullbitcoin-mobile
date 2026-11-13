import 'package:primitives/primitives.dart' show Failure;

sealed class WizardInstallFailure extends Failure {
  const WizardInstallFailure([super.logMessage]);
}

final class WizardInstallStorageFailure extends WizardInstallFailure {
  const WizardInstallStorageFailure([super.logMessage]);
}

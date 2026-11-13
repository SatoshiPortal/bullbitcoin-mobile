import 'package:bb_mobile/core/failures/failure.dart';

sealed class WizardInstallFailure extends Failure {
  const WizardInstallFailure([super.logMessage]);
}

final class WizardInstallStorageFailure extends WizardInstallFailure {
  const WizardInstallStorageFailure([super.logMessage]);
}

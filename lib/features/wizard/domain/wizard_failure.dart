import 'package:bb_mobile/core/failures/failure.dart';

sealed class WizardFailure extends Failure {
  const WizardFailure([super.logMessage]);
}

final class WizardPersistenceFailure extends WizardFailure {
  const WizardPersistenceFailure([super.logMessage]);
}

final class WizardApplyFailure extends WizardFailure {
  const WizardApplyFailure([super.logMessage]);
}

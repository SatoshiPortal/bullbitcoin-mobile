import 'package:primitives/primitives.dart' show Failure;

sealed class WizardFailure extends Failure {
  const WizardFailure();
}

final class WizardSaveFailure extends WizardFailure {
  const WizardSaveFailure();
}

final class WizardApplyFailure extends WizardFailure {
  const WizardApplyFailure();
}

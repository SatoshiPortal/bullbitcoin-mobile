import 'package:bb_mobile/core/failures/failure.dart';

sealed class WizardFailure extends Failure {
  const WizardFailure();
}

final class WizardSaveFailure extends WizardFailure {
  const WizardSaveFailure();
}

final class WizardApplyFailure extends WizardFailure {
  const WizardApplyFailure();
}

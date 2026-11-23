import 'package:primitives/primitives.dart';

sealed class WizardFailure extends Failure {
  const WizardFailure(super.logMessage);
}

final class WizardStorageFailure extends WizardFailure {
  const WizardStorageFailure() : super('Wizard storage unavailable');
}

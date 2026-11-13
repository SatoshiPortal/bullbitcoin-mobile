import 'package:primitives/primitives.dart' show Result;
import 'package:bb_mobile/features/wizard/domain/wizard_install_failure.dart';

abstract interface class WizardInstallRepository {
  Future<Result<bool, WizardInstallFailure>> shouldRunWizard();
}

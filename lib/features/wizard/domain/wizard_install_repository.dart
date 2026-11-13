import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wizard/domain/wizard_install_failure.dart';

abstract interface class WizardInstallRepository {
  Future<Result<bool, WizardInstallFailure>> shouldRunWizard();
}

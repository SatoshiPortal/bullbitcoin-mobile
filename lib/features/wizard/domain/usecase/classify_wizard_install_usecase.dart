import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wizard/domain/wizard_install_failure.dart';
import 'package:bb_mobile/features/wizard/domain/wizard_install_repository.dart';

class ClassifyWizardInstallUsecase {
  const ClassifyWizardInstallUsecase(this._repository);

  final WizardInstallRepository _repository;

  Future<Result<bool, WizardInstallFailure>> execute() =>
      _repository.shouldRunWizard();
}

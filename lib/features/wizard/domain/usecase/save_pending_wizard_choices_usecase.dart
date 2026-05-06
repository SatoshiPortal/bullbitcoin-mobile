import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';

class SavePendingWizardChoicesUsecase {
  SavePendingWizardChoicesUsecase({required WizardRepository repository})
    : _repository = repository;

  final WizardRepository _repository;

  Future<void> execute(WizardChoices choices) =>
      _repository.savePending(choices);
}

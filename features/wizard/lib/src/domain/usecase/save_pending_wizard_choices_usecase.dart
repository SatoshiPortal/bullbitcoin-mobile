import 'package:wizard/src/domain/entity/wizard_choices.dart';
import 'package:wizard/src/domain/repository/wizard_repository.dart';

class SavePendingWizardChoicesUsecase {
  SavePendingWizardChoicesUsecase({required this._repository});

  final WizardRepository _repository;

  Future<void> execute(WizardChoices choices) =>
      _repository.savePending(choices);
}

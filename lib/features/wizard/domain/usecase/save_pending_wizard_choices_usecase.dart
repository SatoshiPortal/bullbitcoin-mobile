import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wizard/domain/wizard_failure.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';

class SavePendingWizardChoicesUsecase {
  SavePendingWizardChoicesUsecase({required this._repository});

  final WizardRepository _repository;

  Future<Result<void, WizardFailure>> execute(WizardChoices choices) =>
      _repository.savePending(choices);
}

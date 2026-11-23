import 'package:wizard/src/domain/entity/wizard_choices.dart';
import 'package:wizard/src/domain/repository/wizard_repository.dart';

class ReadPendingWizardChoicesUsecase {
  ReadPendingWizardChoicesUsecase({required this._repository});

  final WizardRepository _repository;

  Future<WizardChoices?> execute() => _repository.readPending();
}

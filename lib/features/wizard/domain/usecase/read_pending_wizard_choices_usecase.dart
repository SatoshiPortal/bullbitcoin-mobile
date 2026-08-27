import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';

class ReadPendingWizardChoicesUsecase {
  ReadPendingWizardChoicesUsecase({required this._repository});

  final WizardRepository _repository;

  Future<WizardChoices?> execute() => _repository.readPending();
}

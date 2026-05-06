import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';

class IsWizardCompleteUsecase {
  IsWizardCompleteUsecase({required WizardRepository repository})
    : _repository = repository;

  final WizardRepository _repository;

  Future<bool> execute() => _repository.isComplete();
}

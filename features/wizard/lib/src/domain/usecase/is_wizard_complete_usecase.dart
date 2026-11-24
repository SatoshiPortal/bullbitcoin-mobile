import 'package:wizard/src/domain/repository/wizard_repository.dart';

class IsWizardCompleteUsecase {
  IsWizardCompleteUsecase({required this._repository});

  final WizardRepository _repository;

  Future<bool> execute() => _repository.isComplete();
}

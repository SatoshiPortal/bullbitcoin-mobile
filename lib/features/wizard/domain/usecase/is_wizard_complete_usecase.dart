import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';

class IsWizardCompleteUsecase {
  IsWizardCompleteUsecase({required this._repository});

  final WizardRepository _repository;

  Future<bool> execute() => _repository.isComplete();
}

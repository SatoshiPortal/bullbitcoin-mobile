import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';

/// Advances the persisted wizard version marker. Invoked by
/// `WizardBloc._onCompleted` after `SavePendingWizardChoicesUsecase`.
/// `ApplyPendingWizardChoicesUsecase` calls it again post-locator
/// (idempotent).
class MarkWizardCompleteUsecase {
  MarkWizardCompleteUsecase({required WizardRepository repository})
    : _repository = repository;

  final WizardRepository _repository;

  Future<void> execute() => _repository.markComplete();
}

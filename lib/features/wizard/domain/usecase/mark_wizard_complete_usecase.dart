import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wizard/domain/wizard_failure.dart';
import 'package:bb_mobile/features/wizard/domain/repository/wizard_repository.dart';

/// Advances the persisted wizard version marker. Invoked by
/// `WizardBloc._onCompleted` after `SavePendingWizardChoicesUsecase`.
/// `ApplyPendingWizardChoicesUsecase` calls it again post-locator
/// (idempotent).
class MarkWizardCompleteUsecase {
  MarkWizardCompleteUsecase({required this._repository});

  final WizardRepository _repository;

  Future<Result<void, WizardFailure>> execute() => _repository.markComplete();
}

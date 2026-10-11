import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/apply_pending_wizard_choices_usecase.dart';
import 'package:bb_mobile/features/wizard/domain/wizard_failure.dart';

export '../domain/wizard_failure.dart';

class WizardFacade {
  final ApplyPendingWizardChoicesUsecase _apply;
  const WizardFacade(this._apply);
  Future<Result<void, WizardFailure>> applyPendingBackupChoice() =>
      _apply.execute(backupReady: true);
}

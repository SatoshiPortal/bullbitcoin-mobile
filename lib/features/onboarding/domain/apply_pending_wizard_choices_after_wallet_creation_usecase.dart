import 'package:bb_mobile/features/wizard/public/wizard_facade.dart';
import 'package:primitives/primitives.dart';

class ApplyPendingWizardChoicesAfterWalletCreationUsecase {
  final WizardFacade _wizard;

  const ApplyPendingWizardChoicesAfterWalletCreationUsecase(this._wizard);

  Future<Result<void, WizardFailure>> execute() =>
      _wizard.applyPendingChoices();
}

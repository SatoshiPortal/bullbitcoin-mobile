import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/wizard/domain/wizard_failure.dart';
import 'package:flutter/widgets.dart';

extension WizardFailureL10n on WizardFailure {
  String toTranslated(BuildContext context) => switch (this) {
    WizardSaveFailure() ||
    WizardApplyFailure() => context.loc.wizardDataBackupSaveFailed,
  };
}

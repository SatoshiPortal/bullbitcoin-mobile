import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';

import 'ark_l10n.dart';

/// Reports the backend status, not an independently verified chain outcome.
extension ArkOperationStatusL10n on ArkOperationStatus {
  String toTranslated(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    return switch (this) {
      ArkOperationStatus.prepared => l10n.operationPrepared,
      ArkOperationStatus.admitted => l10n.operationAdmitted,
      ArkOperationStatus.pending => l10n.operationPending,
      ArkOperationStatus.succeeded => l10n.operationCompleted,
      ArkOperationStatus.failed => l10n.operationFailed,
      ArkOperationStatus.outcomeUnknown => l10n.operationUnknown,
      ArkOperationStatus.conflicted => l10n.operationConflicted,
    };
  }
}

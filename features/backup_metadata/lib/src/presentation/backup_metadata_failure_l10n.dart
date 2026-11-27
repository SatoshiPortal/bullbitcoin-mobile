import 'package:flutter/widgets.dart';

import '../../generated/l10n/backup_metadata_localizations.dart';
import '../domain/backup_metadata_failure.dart';

extension BackupMetadataFailureL10n on BackupMetadataFailure {
  String toTranslated(BuildContext context) {
    final l10n = BackupMetadataLocalizations.of(context);
    return switch (this) {
      BackupMetadataNotReadyFailure() => l10n.failureNotReady,
      BackupMetadataStalePlanFailure() => l10n.failureStalePlan,
      BackupMetadataTooLargeFailure() => l10n.failureTooLarge,
      BackupMetadataScopeChangedFailure() => l10n.failureScopeChanged,
      BackupMetadataIncompatibleFailure() => l10n.failureIncompatible,
      BackupMetadataAccountChangedFailure() => l10n.failureAccountChanged,
      BackupMetadataUnexpectedFailure() => l10n.failureUnexpected,
    };
  }
}

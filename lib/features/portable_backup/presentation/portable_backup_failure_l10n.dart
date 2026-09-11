import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/portable_backup/domain/portable_backup_failure.dart';
import 'package:flutter/widgets.dart';

extension PortableBackupFailureL10n on PortableBackupFailure {
  String toTranslated(BuildContext context) => switch (this) {
    PortableBackupInvalidPasswordFailure() =>
      context.loc.portableBackupInvalidWords,
    PortableBackupInvalidDataFailure() => context.loc.portableBackupInvalidFile,
    PortableBackupDecryptFailure() => context.loc.portableBackupDecryptFailed,
    PortableBackupNetworkFailure() => context.loc.portableBackupNetworkFailed,
    PortableBackupCancelledFailure() => context.loc.cancelButton,
  };
}

import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:flutter/widgets.dart';

extension BackupSettingsFailureL10n on BackupSettingsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    BackupSettingsUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}

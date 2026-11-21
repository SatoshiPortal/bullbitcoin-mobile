import 'package:flutter/widgets.dart';

import '../domain/fee_source_settings_failure.dart';
import '../fees_l10n.dart';

extension FeeSourceSettingsFailureL10n on FeeSourceSettingsFailure {
  String toTranslated(BuildContext context) {
    final copy = feesCopy(Localizations.localeOf(context).languageCode);
    return switch (this) {
      FeeSourceSettingsLoadFailure() => copy.loadError,
      FeeSourceSettingsSaveFailure() => copy.saveError,
    };
  }
}

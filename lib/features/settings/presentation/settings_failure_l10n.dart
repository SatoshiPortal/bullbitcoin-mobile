import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:flutter/widgets.dart';

extension SettingsFailureL10n on SettingsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    SettingsStorageFailure() => context.loc.oopsSomethingWentWrong,
    SettingsConsentFailure() => context.loc.oopsSomethingWentWrong,
    SettingsPayjoinFailure() => context.loc.oopsSomethingWentWrong,
  };
}

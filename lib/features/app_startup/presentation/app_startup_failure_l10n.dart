import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:flutter/widgets.dart';

extension AppStartupFailureL10n on AppStartupFailure {
  String toTranslated(BuildContext context) => switch (this) {
    AppStartupKeychainLockedFailure() ||
    AppStartupWalletCheckFailure() ||
    AppStartupLegacyCheckFailure() ||
    AppStartupLegacySeedsFailure() ||
    AppStartupResetFailure() ||
    AppStartupPinCheckFailure() => context.loc.appStartupErrorMessage,
  };
}

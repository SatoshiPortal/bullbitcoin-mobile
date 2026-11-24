import 'package:startup/src/l10n.dart';
import 'package:startup/src/domain/app_startup_failure.dart';
import 'package:flutter/widgets.dart';

extension AppStartupFailureL10n on AppStartupFailure {
  String toTranslated(BuildContext context) => switch (this) {
    AppStartupKeychainLockedFailure() ||
    AppStartupWalletCheckFailure() ||
    AppStartupResetFailure() ||
    AppStartupPinCheckFailure() ||
    AppStartupRestoreFailure() => context.loc.appStartupErrorMessage,
    AppStartupMissingDefaultSecretFailure() =>
      context.loc.appStartupMissingSecretMessage,
    AppStartupRestoreMismatchFailure() => context.loc.appStartupRestoreMismatch,
  };
}

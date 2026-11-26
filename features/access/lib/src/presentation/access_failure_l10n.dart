import 'package:access/src/access_l10n.dart';
import 'package:access/src/domain/access_failure.dart';
import 'package:flutter/widgets.dart';

/// Keeps operation-specific messages; diagnostic strings never reach the UI.
extension AccessFailureL10n on AccessFailure {
  String toTranslated(BuildContext context) => switch (this) {
    AccessPinCheckFailure() ||
    AccessUnlockKeychainLockedFailure() => context.loc.appUnlockPinCheckError,
    AccessPinVerifyFailure() => context.loc.appUnlockPinVerifyError,
    AccessPinSaveFailure() => context.loc.pinCodeSaveError,
    AccessPinDeleteFailure() => context.loc.pinCodeDeleteError,
    AccessPinNotSetFailure() => context.loc.pinCodeNotSetError,
    AccessPinSettingsKeychainLockedFailure() ||
    AccessUnlockUnexpectedFailure() ||
    AccessPinSettingsUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}

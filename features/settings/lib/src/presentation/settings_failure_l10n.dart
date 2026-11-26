import 'package:settings/src/l10n.dart';
import 'package:settings/src/domain/settings_failure.dart';
import 'package:flutter/widgets.dart';

extension SettingsFailureL10n on SettingsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    SettingsWalletSyncFailure() => context.loc.walletDiscoveryFailed,
    SettingsStorageFailure() => context.loc.settingsErrorSavingSetting,
    SettingsConsentFailure() => context.loc.settingsErrorConsentNotGiven,
    SettingsLogsFailure() => context.loc.settingsErrorLoadingLogs,
    SettingsExchangeSyncFailure() => context.loc.settingsErrorSavingSetting,
    SettingsNetworkUnavailableFailure() => context.loc.oopsSomethingWentWrong,
    SettingsUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}

import '../domain/recoverbull_failure.dart';
import 'package:flutter/widgets.dart';
import '../l10n/context_localizations.dart';

/// User-facing, localized message for each [RecoverBullFailure]. The `sealed`
/// switch makes a missing message a compile error. Never returns the raw
/// `logMessage`.
extension RecoverBullFailureL10n on RecoverBullFailure {
  String toTranslated(BuildContext context) => switch (this) {
    SelectVaultFailure() => context.loc.recoverbullErrorSelectVault,
    PasswordNotSetFailure() => context.loc.recoverbullErrorPasswordNotSet,
    VaultNotSetFailure() => context.loc.recoverbullErrorVaultNotSet,
    KeyServerConnectionFailure() =>
      context.loc.recoverbullErrorConnectionFailed,
    VaultCreationFailure() => context.loc.recoverbullErrorVaultCreationFailed,
    VaultProviderSaveFailure() => context.loc.recoverbullProviderSaveFailed,
    TorNotStartedFailure() => context.loc.recoverbullTorNotStarted,
    ExternalTorProxyUnavailableFailure() =>
      context.loc.torSettingsExternalProxyUnavailableDescription,
    VaultKeyFetchFailure() => context.loc.recoverbullErrorFetchKeyFailed,
    VaultDecryptionFailure() => context.loc.recoverbullErrorDecryptFailed,
    VaultRecoveryFailure() => context.loc.walletSetupErrorTryAgain,
    InvalidVaultCredentialsFailure() =>
      context.loc.recoverbullErrorInvalidCredentials,
    InvalidVaultFileFormatFailure() =>
      context.loc.recoverbullSelectBackupFileNotValidError,
    VaultRateLimitedFailure(:final retryIn) =>
      context.loc.recoverbullErrorRateLimited(_cooldown(context, retryIn)),
    KeyServerInvalidCredentialsFailure() =>
      context.loc.recoverbullErrorUnexpected,
    KeyServerRateLimitedFailure() => context.loc.recoverbullErrorUnexpected,
    KeyServerRejectedFailure() => context.loc.recoverbullErrorUnexpected,
    KeyServerUnavailableFailure() => context.loc.recoverbullErrorUnexpected,
    InvalidVaultFileFailure() => context.loc.recoverbullErrorUnexpected,
    RecoverBullGoogleDriveFetchFailure() =>
      context.loc.recoverbullGoogleDriveErrorFetchFailed,
    RecoverBullGoogleDriveDeleteFailure() =>
      context.loc.recoverbullGoogleDriveErrorDeleteFailed,
    RecoverBullGoogleDriveExportFailure() =>
      context.loc.recoverbullGoogleDriveErrorExportFailed,
    RecoverBullUnexpectedFailure() => context.loc.recoverbullErrorUnexpected,
  };

  String _cooldown(BuildContext context, Duration retryIn) {
    // Floor unknown/elapsed cooldowns (null mapped to zero, or a negative
    // remaining duration) to 1s so the UI never shows "0 seconds" or a
    // negative value.
    final seconds = retryIn.inSeconds < 1 ? 1 : retryIn.inSeconds;
    if (seconds < 60) {
      return context.loc.durationSeconds(seconds.toString());
    }
    final minutes = seconds ~/ 60;
    return minutes == 1
        ? context.loc.durationMinute(minutes.toString())
        : context.loc.durationMinutes(minutes.toString());
  }
}
